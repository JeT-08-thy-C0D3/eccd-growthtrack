import 'package:flutter/material.dart';
import 'package:eccd_growthtrack/app.dart';
import 'package:eccd_growthtrack/features/auth/data/auth_repository_impl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final authRepo = AuthRepositoryImpl();
  final currentUser = await authRepo.getCurrentUser();
  
  runApp(GrowthTrackApp(initialUser: currentUser));
}
