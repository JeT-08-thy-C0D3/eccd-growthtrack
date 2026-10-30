import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:eccd_growthtrack/firebase_options.dart';
import 'package:eccd_growthtrack/app.dart';
import 'package:eccd_growthtrack/core/config/supabase_config.dart';
import 'package:eccd_growthtrack/features/auth/data/auth_repository_impl.dart';
import 'package:eccd_growthtrack/core/sync/sync_service_web.dart'
    if (dart.library.io) 'package:eccd_growthtrack/core/sync/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Supabase Storage Client
  await SupabaseConfig.initialize();

  // SQLite-backed background synchronization is mobile-only. The web portal
  // reads and writes directly to Firebase instead.
  if (!kIsWeb) {
    SyncService().init();
  }

  final authRepo = AuthRepositoryImpl();
  final currentUser = await authRepo.getCurrentUser();
  final platformInitialRoute =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  // On Flutter Web, the browser URL is available from Uri.base. The platform
  // default route can be just "/", which would discard Firebase's oobCode.
  final initialUri = kIsWeb
      ? Uri.base
      : (Uri.tryParse(platformInitialRoute) ?? Uri());
  final initialRoute = kIsWeb ? initialUri.toString() : platformInitialRoute;
  final initialPasswordResetLink =
      ((initialRoute.contains('resetPassword') ||
              initialUri.path.endsWith('/reset-password') ||
              initialUri.queryParameters['mode'] == 'signIn') &&
          initialUri.queryParameters['oobCode']?.isNotEmpty == true)
      ? initialRoute
      : null;
  final initialPasswordResetSuccess =
      initialUri.queryParameters['passwordReset'] == 'success';

  runApp(
    GrowthTrackApp(
      initialUser: currentUser,
      initialPasswordResetLink: initialPasswordResetLink,
      initialPasswordResetSuccess: initialPasswordResetSuccess,
    ),
  );
}
