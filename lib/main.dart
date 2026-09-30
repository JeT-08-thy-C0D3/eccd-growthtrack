import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:eccd_growthtrack/firebase_options.dart';
import 'package:eccd_growthtrack/app.dart';
import 'package:eccd_growthtrack/core/config/supabase_config.dart';
import 'package:eccd_growthtrack/features/auth/data/auth_repository_impl.dart';
import 'package:eccd_growthtrack/core/sync/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Supabase Storage Client
  await SupabaseConfig.initialize();

  // Start the background synchronization manager
  SyncService().init();

  final authRepo = AuthRepositoryImpl();
  final currentUser = await authRepo.getCurrentUser();

  runApp(
    GrowthTrackApp(
      initialUser: currentUser,
    ),
  );
}
