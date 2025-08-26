import 'package:flutter/material.dart';
import 'athlete_dashboard_screen.dart';
import 'coach_dashboard_screen.dart';
import 'package:trackervest/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Get current user - this should be fast as it's cached
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/welcome');
        return;
      }

      // Load full user data
      final fullUserData = await _firebaseService.getUserData();
      if (!mounted) return;

      // Ensure all required fields are present
      if (fullUserData != null) {
        // Verify required fields
        final requiredFields = ['gender', 'age', 'role', 'name'];
        final missingFields =
            requiredFields
                .where(
                  (field) =>
                      !fullUserData.containsKey(field) ||
                      fullUserData[field] == null,
                )
                .toList();

        if (missingFields.isEmpty) {
          setState(() {
            _userData = fullUserData;
            _isLoading = false;
          });
        } else {
          print('❌ Missing required fields: $missingFields');
          // Update user data with default values for missing fields
          final updatedData = Map<String, dynamic>.from(fullUserData);
          if (!updatedData.containsKey('gender') ||
              updatedData['gender'] == null) {
            updatedData['gender'] = 'Male';
          }
          if (!updatedData.containsKey('age') || updatedData['age'] == null) {
            updatedData['age'] = 25;
          }
          if (!updatedData.containsKey('role') || updatedData['role'] == null) {
            updatedData['role'] = 'athlete';
          }
          if (!updatedData.containsKey('name') || updatedData['name'] == null) {
            updatedData['name'] = user.displayName ?? 'User';
          }

          // Save the updated data to Firestore
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(updatedData, SetOptions(merge: true));

          setState(() {
            _userData = updatedData;
            _isLoading = false;
          });
        }
      } else {
        // If no user data found, create default data
        final defaultData = {
          'uid': user.uid,
          'email': user.email,
          'role': 'athlete',
          'name': user.displayName ?? 'User',
          'gender': 'Male',
          'age': 25,
          'heartrate': null,
          'temp': null,
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Save default data to Firestore
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(defaultData, SetOptions(merge: true));

        setState(() {
          _userData = defaultData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_userData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error loading dashboard'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    () => Navigator.pushReplacementNamed(context, '/welcome'),
                child: const Text('Return to Welcome Screen'),
              ),
            ],
          ),
        ),
      );
    }

    final String role = _userData!['role'] ?? 'athlete';

    if (role == 'coach') {
      return CoachDashboardScreen(userData: _userData!);
    } else {
      return AthleteDashboardScreen(userData: _userData!);
    }
  }
}
