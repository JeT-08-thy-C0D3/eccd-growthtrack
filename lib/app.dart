import 'package:flutter/material.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/admin/presentation/admin_dashboard.dart';
import 'features/teacher/presentation/teacher_dashboard.dart';
import 'features/parent/presentation/parent_dashboard.dart';
import 'features/child_profile/presentation/child_list_page.dart';
import 'features/child_profile/presentation/child_registration_page.dart';
import 'features/attendance/presentation/attendance_page.dart';
import 'features/attendance/presentation/attendance_history_page.dart';
import 'features/eccd_evaluation/presentation/evaluation_page.dart';
import 'features/home_activities/presentation/home_activities_page.dart';
import 'features/referral/presentation/referral_page.dart';
import 'features/reports/presentation/reports_page.dart';
import 'features/reports/presentation/development_summary_page.dart';
import 'features/triangulation/presentation/triangulation_page.dart';
import 'features/parent/presentation/parent_home_activities_page.dart';
import 'features/parent/presentation/feedback_page.dart';
import 'shared/models/user_model.dart';
import 'shared/models/child_model.dart';

class GrowthTrackApp extends StatelessWidget {
  final UserModel? initialUser;
  const GrowthTrackApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
        
        // Teacher Feature Routes
        '/register-child': (context) => const ChildListPage(),
        '/child-registration': (context) => const ChildRegistrationPage(),
        '/attendance': (context) => const AttendancePage(),
        '/eccd-evaluation': (context) => const EvaluationPage(),
        '/home-activities': (context) => const HomeActivitiesPage(),
        '/referrals': (context) => const ReferralPage(),
        '/reports': (context) => const ReportsPage(),
        '/triangulation': (context) => const TriangulationPage(),
        '/ai-summary': (context) => const DevelopmentSummaryPage(),

        // Parent Feature Routes
        '/feedback': (context) => const FeedbackPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/parent-activities') {
          final child = settings.arguments as ChildModel;
          return MaterialPageRoute(
            builder: (context) => ParentHomeActivitiesPage(child: child),
          );
        }
        return null;
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

class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title Page - Coming Soon')),
    );
  }
}
