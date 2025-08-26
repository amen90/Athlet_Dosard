import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUserDocument(
    User user,
    String role, {
    Map<String, dynamic>? userData,
  }) async {
    try {
      // Get name from userData or fallback
      final String userName = userData?['name'] ?? user.displayName ?? 'User';

      // Generate user ID from name
      final String userId = "${userName.replaceAll(' ', '')}ID";

      // Create a base user document
      final Map<String, dynamic> userDoc = {
        'email': user.email,
        'uid': user.uid,
        'role': role,
        'name': userName,
        'id': userId, // Add auto-generated ID
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add athlete-specific fields if role is athlete
      if (role == 'athlete') {
        userDoc['hr'] = null;
        userDoc['temp'] = null;
        userDoc['spo2'] = null;
        userDoc['activity'] = 'Weightlifting';
        userDoc['fatigue_score'] = 5;
      }

      // Merge with any additional user data
      if (userData != null) {
        userDoc.addAll(userData);
        // Make sure the auto-generated ID isn't overwritten if not specified
        if (!userData.containsKey('id')) {
          userDoc['id'] = userId;
        }
      }

      // Save to Firestore users collection
      await _firestore.collection('users').doc(user.uid).set(userDoc);

      print('✅ User document created in Firestore');
      print('Auto-generated user ID: $userId');
      print('Role: $role');
      if (role == 'athlete') {
        print(
          'Athlete-specific fields initialized: hr=null, temp=null, spo2=null',
        );
      }
      userDoc.forEach((key, value) {
        print('   - $key: $value');
      });
    } catch (e) {
      print('❌ Error creating user document: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserData() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return {
          'role': 'athlete',
          'name': 'Default User',
          'id': 'DefaultUserID',
          'gender': 'Male',
          'age': 25,
          'hr': null,
          'temp': null,
          'spo2': null,
          'activity': 'Weightlifting',
          'fatigue_score': 5,
          'createdAt': FieldValue.serverTimestamp(),
        };
      }

      // Try to get user document from Firestore
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      // If the document exists, ensure all required fields are present
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        // Check and add any missing required fields
        final defaultValues = {
          'role': 'athlete',
          'name': currentUser.displayName ?? 'User',
          'id': '${currentUser.displayName ?? 'User'}ID',
          'gender': 'Male',
          'age': 25,
          'hr': null,
          'temp': null,
          'spo2': null,
          'activity': 'Weightlifting',
          'fatigue_score': 5,
          'email': currentUser.email,
          'uid': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        };

        bool needsUpdate = false;
        defaultValues.forEach((key, value) {
          if (!userData.containsKey(key) || userData[key] == null) {
            userData[key] = value;
            needsUpdate = true;
          }
        });

        // If any fields were missing, update the document in Firestore
        if (needsUpdate) {
          print('Updating user document with missing fields');
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .set(userData, SetOptions(merge: true));
        }

        print('✅ User data retrieved/updated in Firestore:');
        userData.forEach((key, value) => print('  $key: $value'));
        return userData;
      }

      // If document doesn't exist, create a new one with all required fields
      final newUserData = {
        'role': 'athlete',
        'name': currentUser.displayName ?? 'User',
        'id': '${currentUser.displayName ?? 'User'}ID',
        'gender': 'Male',
        'age': 25,
        'hr': null,
        'temp': null,
        'spo2': null,
        'activity': 'Weightlifting',
        'fatigue_score': 5,
        'email': currentUser.email,
        'uid': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      print('Creating new user document with all required fields');
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .set(newUserData);

      print('✅ New user data created in Firestore:');
      newUserData.forEach((key, value) => print('  $key: $value'));
      return newUserData;
    } catch (e) {
      print('❌ Error getting user data: $e');
      // Return complete default data in case of error
      return {
        'role': 'athlete',
        'name': 'Default User',
        'id': 'DefaultUserID',
        'gender': 'Male',
        'age': 25,
        'hr': null,
        'temp': null,
        'spo2': null,
        'activity': 'Weightlifting',
        'fatigue_score': 5,
        'createdAt': FieldValue.serverTimestamp(),
        'error': e.toString(),
      };
    }
  }

  // Add new method to get all athletes
  Future<List<Map<String, dynamic>>> getAllAthletes() async {
    try {
      // Query Firestore for all users with role 'athlete'
      final QuerySnapshot athletesSnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'athlete')
              .get();

      // Convert QuerySnapshot to List of Maps
      final List<Map<String, dynamic>> athletes =
          athletesSnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

      print('✅ Retrieved ${athletes.length} athletes from Firestore');
      return athletes;
    } catch (e) {
      print('❌ Error getting athletes: $e');
      return [];
    }
  }

  // Add method to get a specific athlete's data
  Future<Map<String, dynamic>?> getAthleteData(String uid) async {
    try {
      final DocumentSnapshot athleteDoc =
          await _firestore.collection('users').doc(uid).get();

      if (athleteDoc.exists) {
        final athleteData = athleteDoc.data() as Map<String, dynamic>;
        return athleteData;
      }

      return null;
    } catch (e) {
      print('❌ Error getting athlete data: $e');
      return null;
    }
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Authenticate user
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Get complete user data from Firestore
        final userDoc =
            await _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          return {
            'success': true,
            'user': userCredential.user,
            'userData': userData,
            'message': 'Login successful',
          };
        }

        // If user document doesn't exist, create it with default values
        final defaultUserData = {
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email,
          'role': 'athlete',
          'name': userCredential.user!.displayName ?? 'User',
          'gender': 'Male',
          'age': 25,
          'hr': null,
          'temp': null,
          'spo2': null,
          'activity': 'Weightlifting',
          'fatigue_score': 5,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(defaultUserData);

        return {
          'success': true,
          'user': userCredential.user,
          'userData': defaultUserData,
          'message': 'Login successful',
        };
      }

      return {'success': false, 'message': 'Authentication failed'};
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email';
          break;
        case 'wrong-password':
          message = 'Wrong password provided';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      print('Error during login: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String role, {
    Map<String, dynamic>? userData,
  }) async {
    try {
      // Validate inputs
      if (email.isEmpty || password.isEmpty) {
        return {
          'success': false,
          'message': 'Email and password cannot be empty',
        };
      }

      if (password.length < 6) {
        return {
          'success': false,
          'message': 'Password must be at least 6 characters long',
        };
      }

      // Validate age if provided
      if (userData != null && userData.containsKey('age')) {
        int? age = userData['age'];
        if (age == null || age < 0 || age > 120) {
          return {
            'success': false,
            'message': 'Please enter a valid age between 0 and 120',
          };
        }
      }

      // Create user with reCAPTCHA verification
      await _auth.setSettings(appVerificationDisabledForTesting: false);
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        // Create user document with role and additional data
        await _firebaseService.createUserDocument(
          userCredential.user!,
          role,
          userData: userData,
        );

        return {
          'success': true,
          'user': userCredential.user,
          'role': role,
          'userData': userData,
          'message': 'Registration successful',
        };
      } else {
        return {'success': false, 'message': 'Registration failed'};
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'weak-password':
          message = 'Password is too weak';
          break;
        default:
          message = 'Registration failed: ${e.message}';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }
}
