/// Firebase App Check setup for Firebase-protected app features.
library;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;

class AppCheckService {
  static final AppCheckService _instance = AppCheckService._init();

  AppCheckService._init();

  factory AppCheckService() => _instance;

  /// Call this after Firebase.initializeApp().
  Future<void> initialize() async {
    try {
      // Firebase now registers web App Check through Google Cloud Fraud
      // Defense (formerly reCAPTCHA Enterprise). Avoid activating a
      // placeholder because it would break every protected request.
      if (kIsWeb) {
        const webSiteKey = String.fromEnvironment(
          'RECAPTCHA_ENTERPRISE_SITE_KEY',
        );
        if (webSiteKey.isEmpty) return;
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaEnterpriseProvider(webSiteKey),
        );
        // Request a token at startup so a localhost debug build immediately
        // prints the Firebase debug secret in Chrome DevTools. Without this,
        // the token is only requested later by Firebase AI and is easy to
        // miss among the request errors.
        await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
        await FirebaseAppCheck.instance.getToken(true);
        debugPrint('Firebase App Check web token acquired.');
        return;
      }

      await FirebaseAppCheck.instance.activate(
        // Copy the debug token shown in the run log into Firebase App Check
        // during development. Release builds use device attestation instead.
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.deviceCheck,
      );
      debugPrint('Firebase App Check initialized successfully');
    } catch (error) {
      // App Check registration should not stop the whole application from
      // launching; Firebase AI requests will report their own actionable error.
      debugPrint('Firebase App Check initialization warning: $error');
    }
  }

  Future<String?> getToken() async {
    try {
      return await FirebaseAppCheck.instance.getToken(false);
    } catch (error) {
      debugPrint('Error getting App Check token: $error');
      return null;
    }
  }

  Future<String?> refreshToken() async {
    try {
      return await FirebaseAppCheck.instance.getToken(true);
    } catch (error) {
      debugPrint('Error refreshing App Check token: $error');
      return null;
    }
  }

  Stream<String?> get tokenStream => FirebaseAppCheck.instance.onTokenChange;
}
