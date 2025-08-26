import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createUserDocument(
    User user,
    String role, {
    Map<String, dynamic>? userData,
  }) async {
    try {
      // Base user data with default values for all required fields
      final baseUserData = {
        'email': user.email,
        'uid': user.uid,
        'role': role,
        'name': user.displayName ?? 'User',
        'gender': 'male', // Default value
        'age': 25, // Default value
        'hr': null,
        'temp': null,
        'spo2': null,
        'activity': 'Weightlifting', // Default activity
        'fatigue_score': 5, // Default fatigue score (1-10 scale)
        'createdAt': FieldValue.serverTimestamp(),
      };

      // If additional userData is provided, merge it with base data
      final finalUserData =
          userData != null ? {...baseUserData, ...userData} : baseUserData;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(finalUserData, SetOptions(merge: true));

      print('✅ Debug: User document created successfully');
      print('Debug: Created user data:');
      finalUserData.forEach((key, value) => print('  $key: $value'));
    } catch (e) {
      print('❌ Debug: Error creating user document: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final DocumentSnapshot docSnapshot =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (docSnapshot.exists) {
        return docSnapshot.data() as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String> getUserRole() async {
    final userData = await getUserData();
    return userData?['role'] ?? 'athlete';
  }

  // Stream all athletes data in real-time
  Stream<List<Map<String, dynamic>>> streamAllAthletes() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'athlete')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
        });
  }

  // Stream a specific athlete's data in real-time
  Stream<Map<String, dynamic>?> streamAthleteData(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data() as Map<String, dynamic>?);
  }
}
