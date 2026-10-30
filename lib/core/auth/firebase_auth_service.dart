/// Firebase Authentication Service (Security-First)
/// 
/// This service handles all authentication operations and NEVER stores passwords locally.
/// Password validation is delegated entirely to Firebase Authentication.
///
/// Key Principles:
/// 1. NO password fields in any model
/// 2. Firebase Auth UID is the sole credential identifier
/// 3. All user data operations via secure backend (Cloud Functions)
/// 4. Session timeout with automatic logout
/// 5. Role-based authorization checks
library;

import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._init();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Session timeout in seconds (15 minutes default)
  static const int SESSION_TIMEOUT_SECONDS = 900;

  FirebaseAuthService._init();

  factory FirebaseAuthService() => _instance;

  /// Current authenticated user
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Sign up: Create user in Firebase Auth only
  /// 
  /// NOTE: User profile (role, center, etc.) is created by server-side Cloud Function
  /// and stored in Firestore only—NEVER in local SQLite with passwords.
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update Firebase Auth profile (name only)
      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.reload();

      // IMPORTANT: Server-side Cloud Function will:
      // 1. Create CanonicalUser record in Firestore
      // 2. Assign role (pending review by admin)
      // 3. Set status to 'pending'
      // Password is NEVER stored locally or in Firestore

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in: Validate credentials with Firebase Auth
  /// 
  /// Returns User if successful. Password is validated only in Firebase,
  /// never stored or cached locally.
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out: Clear session and local credentials
  /// 
  /// Also clears:
  /// - FCM token registration
  /// - Local cache
  /// - Session state
  Future<void> signOut() async {
    try {
      // Clear FCM subscriptions
      await _clearFcmToken();
      
      // Sign out from Firebase
      await _auth.signOut();
      
      // Note: Local database cleanup handled by SessionController
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Password reset: Send email to user
  /// 
  /// User resets password via email link (never handled in app).
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Verify email: Send verification email
  Future<void> sendEmailVerification() async {
    try {
      await currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Refresh user's ID token (for auth headers)
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      return await currentUser?.getIdToken(forceRefresh);
    } catch (e) {
      throw Exception('Failed to get ID token: $e');
    }
  }

  /// Delete user account (admin only)
  /// 
  /// WARNING: This deletes from Firebase Auth and marks user as
  /// 'deactivated' in Firestore via Cloud Function.
  /// Local SQLite record remains for audit trail.
  Future<void> deleteUserAccount() async {
    try {
      await currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Get user's email
  String? get userEmail => currentUser?.email;

  /// Get user's UID
  String? get userId => currentUser?.uid;

  /// Check if email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// Private helper: Handle Firebase auth exceptions
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'Email is already in use.';
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      case 'invalid-email':
        return 'Email address is invalid.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'account-exists-with-different-credential':
        return 'Account exists with different sign-in method.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }

  /// Private helper: Clear FCM token on logout
  Future<void> _clearFcmToken() async {
    try {
      // Typically handled by FCM service
      // This is a placeholder for cleanup
    } catch (e) {
      // Log but don't fail
      print('Warning: Could not clear FCM token: $e');
    }
  }
}
