import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/terms_and_conditions_screen.dart';
import 'features/teacher/presentation/teacher_dashboard.dart';
import 'features/parent/presentation/parent_dashboard.dart';
import 'features/child_profile/presentation/child_list_page.dart';
import 'features/child_profile/presentation/child_registration_page.dart';
import 'features/attendance/presentation/attendance_page.dart';
import 'features/eccd_evaluation/presentation/evaluation_page.dart';
import 'features/home_activities/presentation/activity_management_page.dart';
import 'features/referral/presentation/referral_page.dart';
import 'features/reports/presentation/reports_page.dart';
import 'features/reports/presentation/development_summary_page.dart';
import 'features/triangulation/presentation/triangulation_page.dart';
import 'features/parent/presentation/parent_feedback_page.dart';
import 'features/parent/presentation/parent_feedback_history_page.dart';
import 'features/parent/presentation/parent_clarification_page.dart';
import 'features/teacher/presentation/teacher_clarifications_page.dart';
import 'features/notification/presentation/parent_notifications_page.dart';
import 'features/development_practice_activities/presentation/pages/practice_activities_page.dart';
import 'features/development_practice_activities/presentation/pages/completed_activities_page.dart';
import 'features/admin/presentation/admin_dashboard_page.dart';
import 'features/admin/presentation/user_management_page.dart';
import 'features/admin/presentation/child_monitoring_page.dart';
import 'features/admin/presentation/referral_monitoring_page.dart';
import 'features/admin/presentation/audit_trail_page.dart';
import 'features/admin/presentation/admin_reports_page.dart';
import 'features/admin/presentation/system_settings_page.dart';
import 'shared/models/user_model.dart';

class GrowthTrackApp extends StatelessWidget {
  final UserModel? initialUser;
  const GrowthTrackApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    final Map<String, WidgetBuilder> appRoutes = {
      '/login': (context) => const LoginPage(),
      '/terms': (context) => const TermsAndConditionsScreen(),
      '/admin': (context) => _buildAdminRoute(),
      '/admin/users': (context) => const UserManagementPage(),
      '/admin/monitoring': (context) => const ChildMonitoringPage(),
      '/admin/referrals': (context) => const ReferralMonitoringPage(),
      '/admin/audit': (context) => const AuditTrailPage(),
      '/admin/reports': (context) => const AdminReportsPage(),
      '/admin/settings': (context) => const SystemSettingsPage(),
      '/teacher': (context) => _buildTeacherRoute(),
      '/parent': (context) => _buildParentRoute(),
      
      // Feature Routes
      '/register-child': (context) => const ChildListPage(),
      '/child-registration': (context) => const ChildRegistrationPage(),
      '/attendance': (context) => const AttendancePage(),
      '/eccd-evaluation': (context) => const EvaluationPage(),
      '/home-activities': (context) => const ActivityManagementPage(),
      '/referrals': (context) => const ReferralPage(),
      '/reports': (context) => const ReportsPage(),
      '/triangulation': (context) => const TriangulationPage(),
      '/ai-summary': (context) => const DevelopmentSummaryPage(),
      '/feedback': (context) => const ParentFeedbackPage(),
      '/feedback-history': (context) => const ParentFeedbackHistoryPage(),
      '/clarifications': (context) => const ParentClarificationPage(),
      '/teacher/clarifications': (context) => const TeacherClarificationsPage(),
      '/parent/notifications': (context) => const ParentNotificationsPage(),
      '/parent/practice-activities': (context) => const PracticeActivitiesPage(),
      '/parent/practice-activities/completed': (context) => const CompletedActivitiesPage(),
    };

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ECCD GrowthTrack',
          themeMode: currentThemeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.blue,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.blue,
            brightness: Brightness.dark,
          ),
          initialRoute: initialUser == null ? '/login' : _getInitialRoute(initialUser!.role),
          onGenerateRoute: (settings) {
            final name = settings.name;
            
            // Web Platform Guard: Block direct URL access to mobile-only routes
            if (kIsWeb && (name == '/teacher' || name == '/parent')) {
              return MaterialPageRoute(
                settings: settings,
                builder: (context) => const PlatformErrorPage(requiredPlatform: 'Mobile App'),
              );
            }

            final builder = appRoutes[name];
            if (builder != null) {
              return MaterialPageRoute(settings: settings, builder: builder);
            }

            return MaterialPageRoute(
              settings: settings,
              builder: (context) => const LoginPage(),
            );
          },
        );
      },
    );
  }

  Widget _buildAdminRoute() {
    if (!kIsWeb) {
      return const PlatformErrorPage(requiredPlatform: 'Web');
    }
    return const AdminDashboardPage();
  }

  Widget _buildTeacherRoute() {
    if (kIsWeb) {
      return const PlatformErrorPage(requiredPlatform: 'Mobile App');
    }
    return const TeacherDashboard();
  }

  Widget _buildParentRoute() {
    if (kIsWeb) {
      return const PlatformErrorPage(requiredPlatform: 'Mobile App');
    }
    return const ParentDashboard();
  }

  String _getInitialRoute(UserRole role) {
    switch (role) {
      case UserRole.admin: return '/admin';
      case UserRole.teacher: return '/teacher';
      case UserRole.parent: return '/parent';
    }
  }
}

class PlatformErrorPage extends StatelessWidget {
  final String requiredPlatform;
  const PlatformErrorPage({super.key, required this.requiredPlatform});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phonelink_erase, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                'Invalid Platform',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'This dashboard is only available on $requiredPlatform.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
