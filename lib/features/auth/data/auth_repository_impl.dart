import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kIsWeb;

import '../../../shared/models/user_model.dart';
import '../domain/auth_repository.dart';
import '../../../core/utils/audit_logger.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/fcm_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _userKey = 'logged_in_user_id';
  static const String _passwordRecoveryUrl =
      'https://eccd-growthtrack.firebaseapp.com/reset-password';

  /// Safe to use for cache lookup only. Access control continues to use the
  /// server-validated profile in [getCurrentUser].
  String? get firebaseUserId => _firebaseAuth.currentUser?.uid;

  @override
  Future<UserModel?> login(String email, String password) async {
    try {
      final UserCredential credential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      if (credential.user != null) {
        DocumentSnapshot<Map<String, dynamic>> doc;
        try {
          // Never use a cached profile for access control. An administrator may
          // have deactivated this account moments ago on another device.
          doc = await _firestore
              .collection('users')
              .doc(credential.user!.uid)
              .get(const GetOptions(source: Source.server));
        } catch (e) {
          throw 'Cloud database is currently unavailable. Please check your internet connection.';
        }

        if (!doc.exists &&
            credential.user!.email?.trim().toLowerCase() ==
                'johnexiquel.idian@gmail.com') {
          // The previous admin profile used a stale UID. The server-side,
          // one-time migration copies the safe profile fields to this verified
          // Firebase Authentication UID and removes the obsolete document.
          await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
              .httpsCallable('bootstrapReplacementAdmin')
              .call();
          doc = await _firestore
              .collection('users')
              .doc(credential.user!.uid)
              .get(const GetOptions(source: Source.server));
        }

        if (doc.exists) {
          final user = UserModel.fromMap(doc.data()!);

          // Firebase Auth can still have a valid credential while an admin has
          // deactivated the profile in Firestore. Always check the latest
          // profile status before completing sign-in.
          if (user.status.trim().toLowerCase() != 'active') {
            await _firebaseAuth.signOut();
            throw 'This account has been deactivated by the administrator.';
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userKey, user.uid);

          if (!kIsWeb) {
            await DatabaseHelper.instance.insertRecord('users', user.toMap());
          }

          // Web push needs a separate service-worker/VAPID configuration.
          // Keep web sign-in independent from mobile FCM setup.
          if (!kIsWeb) {
            await FcmService().initializeAndSyncToken(user.uid);
          }

          await AuditLogger.log(
            action: 'Login',
            module: 'Authentication',
            description:
                'User ${user.email} logged in successfully via Firebase.',
          );

          return user;
        } else {
          throw 'User profile record not found in system database.';
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          throw 'Invalid email address or password. Please check your credentials.';
        case 'invalid-email':
          throw 'The email address format is invalid.';
        case 'user-disabled':
          throw 'This account has been disabled by the administrator.';
        case 'too-many-requests':
          throw 'Too many failed login attempts. Please try again later.';
        case 'network-request-failed':
          throw 'No internet connection. Please check your network and try again.';
        default:
          throw e.message ?? 'Authentication failed. Please try again.';
      }
    } catch (e, stackTrace) {
      debugPrint('Login error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (e is String) rethrow;
      throw 'An unexpected error occurred during login. Please try again.';
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      // The Gmail link proves ownership of the account, then the app lets the
      // verified user set a new password. This uses only Firebase Auth, so it
      // works on the Spark plan without a Cloud Function.
      await _firebaseAuth.sendSignInLinkToEmail(
        email: normalizedEmail,
        actionCodeSettings: ActionCodeSettings(
          url: Uri.parse(_passwordRecoveryUrl)
              .replace(queryParameters: {'email': normalizedEmail})
              .toString(),
          handleCodeInApp: true,
        ),
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('password_reset_email', normalizedEmail);

      // Keep an auditable reset state in Firestore so admins can see that the
      // verification email was requested.
      try {
        final matchingUsers = await _firestore
            .collection('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        final request = <String, dynamic>{
          'email': normalizedEmail,
          'status': 'sent',
          'requested_at': FieldValue.serverTimestamp(),
        };
        if (matchingUsers.docs.isNotEmpty) {
          final uid = matchingUsers.docs.first.id;
          request['uid'] = uid;
          await _firestore.collection('users').doc(uid).set({
            'password_reset_status': 'sent',
            'password_reset_requested_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await _firestore.collection('password_reset_requests').add(request);
      } catch (e) {
        // Do not hide a successfully sent Firebase reset email when the
        // optional audit write is blocked by offline/security-rule conditions.
        debugPrint('Password reset audit write failed: $e');
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw 'The email address format is invalid.';
        case 'user-not-found':
          throw 'No account was found for this email address.';
        case 'network-request-failed':
          throw 'No internet connection. Please try again.';
        default:
          throw e.message ?? 'Unable to send the password reset email.';
      }
    }
  }

  @override
  Future<void> logout() async {
    try {
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
    } catch (e) {
      debugPrint('Logout Error: $e');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final User? firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        final doc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get(const GetOptions(source: Source.server));
        if (doc.exists) {
          final user = UserModel.fromMap(doc.data()!);
          if (user.status.trim().toLowerCase() != 'active') {
            await _firebaseAuth.signOut();
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_userKey);
            return null;
          }
          if (!kIsWeb) {
            FcmService().initializeAndSyncToken(user.uid);
          }
          return user;
        }
      }
      return null;
    } catch (e) {
      debugPrint('getCurrentUser error: $e');
      return null;
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    return _firebaseAuth.currentUser != null;
  }
}
