import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/reset_password_page.dart';
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
import 'shared/widgets/brand_widgets.dart';

class GrowthTrackApp extends StatelessWidget {
  final UserModel? initialUser;
  final String? initialPasswordResetLink;
  final bool initialPasswordResetSuccess;
  const GrowthTrackApp({
    super.key,
    this.initialUser,
    this.initialPasswordResetLink,
    this.initialPasswordResetSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, WidgetBuilder> appRoutes = {
      '/login': (context) =>
          LoginPage(showPasswordResetSuccess: initialPasswordResetSuccess),
      '/intro': (context) => _IntroSplashPage(nextRoute: _initialRoute()),
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
      '/parent/practice-activities': (context) =>
          const PracticeActivitiesPage(),
      '/parent/practice-activities/completed': (context) =>
          const CompletedActivitiesPage(),
    };

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ECCD GrowthTrack',
          themeMode: currentThemeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          // Keep every teacher/parent page above the Android system navigation
          // area, including pages with bottom actions or scrolling forms.
          builder: (context, child) => SafeArea(
            top: false,
            bottom: true,
            child: child ?? const SizedBox.shrink(),
          ),
          initialRoute: '/intro',
          onGenerateRoute: (settings) {
            final name = settings.name;
            if (name == '/email-link-recovery' &&
                initialPasswordResetLink != null) {
              final email =
                  Uri.tryParse(initialPasswordResetLink!)
                      ?.queryParameters['email'] ??
                  '';
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => ResetPasswordPage(
                  emailLink: initialPasswordResetLink,
                  initialEmail: email,
                ),
              );
            }
            final emailLink = _emailSignInLinkFromRoute(name);
            if (emailLink != null) {
              final email =
                  Uri.tryParse(name ?? '')?.queryParameters['email'] ?? '';
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => ResetPasswordPage(
                  emailLink: emailLink,
                  initialEmail: email,
                ),
              );
            }
            final resetCode = _passwordResetCodeFromRoute(name);
            if (resetCode != null) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => ResetPasswordPage(actionCode: resetCode),
              );
            }
            final builder = appRoutes[name];
            if (builder != null) {
              return MaterialPageRoute(settings: settings, builder: builder);
            }

            return MaterialPageRoute(
              settings: settings,
              builder: (context) => LoginPage(
                showPasswordResetSuccess: initialPasswordResetSuccess,
              ),
            );
          },
        );
      },
    );
  }

  String? _passwordResetCodeFromRoute(String? route) {
    if (route == null || !route.contains('resetPassword')) return null;
    final uri = Uri.tryParse(route);
    final code = uri?.queryParameters['oobCode'];
    return (code == null || code.isEmpty) ? null : code;
  }

  String? _emailSignInLinkFromRoute(String? route) {
    final uri = Uri.tryParse(route ?? '');
    final code = uri?.queryParameters['oobCode'];
    final isRecoveryPath = uri?.path.endsWith('/reset-password') == true;
    return (uri?.queryParameters['mode'] == 'signIn' || isRecoveryPath) &&
            code != null &&
            code.isNotEmpty
        ? route
        : null;
  }

  String _initialRoute() {
    if (_emailSignInLinkFromRoute(initialPasswordResetLink) != null) {
      return '/email-link-recovery';
    }
    return initialPasswordResetLink ??
        (initialUser == null ? '/login' : _getInitialRoute(initialUser!.role));
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.navy,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? BrandColors.sky : BrandColors.navy,
          secondary: BrandColors.green,
          tertiary: BrandColors.sunshine,
          surface: isDark ? const Color(0xFF101C24) : BrandColors.canvas,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: isDark ? Colors.white : BrandColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF172731) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        // Use the compact outlined field style consistently across every form.
        // Labels stay above the border so they never cover entered values.
        filled: false,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        labelStyle: const TextStyle(fontSize: 12),
        floatingLabelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          height: 1.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
    );
  }

  Widget _buildAdminRoute() => const AdminDashboardPage();

  Widget _buildTeacherRoute() => const TeacherDashboard();

  Widget _buildParentRoute() => const ParentDashboard();

  String _getInitialRoute(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return '/admin';
      case UserRole.teacher:
        return '/teacher';
      case UserRole.parent:
        return '/parent';
    }
  }
}

class _IntroSplashPage extends StatefulWidget {
  const _IntroSplashPage({required this.nextRoute});
  final String nextRoute;

  @override
  State<_IntroSplashPage> createState() => _IntroSplashPageState();
}

class _IntroSplashPageState extends State<_IntroSplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..forward();
    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(widget.nextRoute);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7FCFF), Color(0xFFE1F4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final fade = Curves.easeInOutCubic.transform(
              (_controller.value / .7).clamp(0.0, 1.0),
            );
            final scale = Curves.easeOutBack
                .transform((_controller.value / .85).clamp(0.0, 1.0))
                .clamp(0.0, 1.0);
            return Opacity(
              opacity: fade,
              child: Transform.translate(
                offset: Offset(0, 22 * (1 - fade)),
                child: Transform.scale(
                  scale: .78 + (.22 * scale),
                  child: child,
                ),
              ),
            );
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EccdLogo(width: 170, height: 170),
              SizedBox(height: 20),
              Text(
                'ECCD GrowthTrack',
                style: TextStyle(
                  color: BrandColors.navy,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Supporting every child’s growth',
                style: TextStyle(color: Color(0xFF54769B), fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'This dashboard is only available on $requiredPlatform.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
