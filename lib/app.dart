import 'package:flutter/material.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/admin/presentation/admin_dashboard.dart';
import 'features/teacher/presentation/teacher_dashboard.dart';
import 'features/parent/presentation/parent_dashboard.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'shared/models/user_model.dart';

class GrowthTrackApp extends StatelessWidget {
  final UserModel? initialUser;
  const GrowthTrackApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECCD GrowthTrack',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      initialRoute: initialUser == null ? '/login' : _getInitialRoute(initialUser!.role),
      routes: {
        '/login': (context) => const LoginPage(),
        '/admin': (context) => const AdminDashboard(),
        '/teacher': (context) => const TeacherDashboard(),
        '/parent': (context) => const ParentDashboard(),
      },
    );
  }

  String _getInitialRoute(UserRole role) {
    switch (role) {
      case UserRole.admin: return '/admin';
      case UserRole.teacher: return '/teacher';
      case UserRole.parent: return '/parent';
    }
  }
}
