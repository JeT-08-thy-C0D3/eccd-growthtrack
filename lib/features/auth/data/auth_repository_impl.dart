import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/user_model.dart';
import '../domain/auth_repository.dart';
import '../../../core/utils/audit_logger.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _userKey = 'logged_in_user_id';

  @override
  Future<UserModel?> login(String email, String password) async {
    try {
      final UserCredential credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final doc = await _firestore.collection('users').doc(credential.user!.uid).get();
        
        if (doc.exists) {
          final user = UserModel.fromMap(doc.data()!);
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userKey, user.uid);
          
          await AuditLogger.log(
            action: 'Login',
            module: 'Authentication',
            description: 'User ${user.email} logged in successfully via Firebase.',
          );
          
          return user;
        }
      }
      return null;
    } catch (e) {
      print('Auth Error: $e');
      return null;
    }
  }

  @override
  Future<void> logout() async {
    final user = await getCurrentUser();
    await _firebaseAuth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    
    if (user != null) {
      await AuditLogger.log(
        action: 'Logout',
        module: 'Authentication',
        description: 'User ${user.email} logged out from Firebase.',
      );
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final User? firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
    }
    return null;
  }

  @override
  Future<bool> isLoggedIn() async {
    return _firebaseAuth.currentUser != null;
  }
}
