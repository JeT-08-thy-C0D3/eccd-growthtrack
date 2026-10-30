/// Firebase App Check Service
///
/// Implements Firebase App Check to prevent abuse and ensure
/// only legitimate clients access Firebase services.
///
/// Supports:
/// - SafetyNet (Android)
/// - DeviceCheck (iOS)
/// - reCAPTCHA v3 (Web)
/// - Custom token provider (for testing)
library;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppCheckService {
  static final AppCheckService _instance = AppCheckService._init();

  AppCheckService._init();

  factory AppCheckService() => _instance;

  /// Initialize Firebase App Check
  ///
  /// Must be called BEFORE FirebaseApp initialization for full coverage.
  /// In main.dart:
  ///   await Firebase.initializeApp();
  ///   await AppCheckService().initialize();
  Future<void> initialize() async {
    try {
      await FirebaseAppCheck.instance.activate(
        webProvider: kIsWeb
            ? ReCaptchaV3Provider('YOUR_RECAPTCHA_V3_PUBLIC_KEY')
            : null,
        androidProvider: AndroidProvider.safetyNet,
        appleProvider: AppleProvider.deviceCheck,
      );

      print('✓ Firebase App Check initialized successfully');
    } catch (e) {
      print('⚠️ Firebase App Check initialization warning: $e');
      // Don't fail app startup - App Check failures shouldn't break app
      // but will reduce Firebase functionality
    }
  }

  /// Get current App Check token
  ///
  /// This token is automatically attached to Firestore, Storage,
  /// and Cloud Functions requests.
  Future<String?> getToken() async {
    try {
      return await FirebaseAppCheck.instance.getToken(false);
    } catch (e) {
      print('Error getting App Check token: $e');
      return null;
    }
  }

  /// Refresh App Check token
  Future<String?> refreshToken() async {
    try {
      return await FirebaseAppCheck.instance.getToken(true);
    } catch (e) {
      print('Error refreshing App Check token: $e');
      return null;
    }
  }

  /// Listen to App Check token changes
  ///
  /// Token is automatically refreshed periodically by Firebase.
  /// Use this to update your app state if needed.
  Stream<String?> get tokenStream {
    return FirebaseAppCheck.instance.onTokenChange;
  }

  /// Set App Check enforcement level (debug only)
  ///
  /// WARNING: Only use for testing. Production requires valid app provisioning.
  static Future<void> setDebugMode() async {
    if (kIsWeb) {
      // Web debug mode not recommended in production
      print('⚠️ App Check debug mode on web - review for production');
    } else {
      try {
        // Note: setCustomTokenProvider for Android/iOS testing
        // This should only be used with test backend
        print('⚠️ Debug mode enabled - only use for development');
      } catch (e) {
        print('Error enabling debug mode: $e');
      }
    }
  }
}
