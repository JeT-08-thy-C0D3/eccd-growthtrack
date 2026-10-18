import 'package:flutter/material.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const EccdAppBarTitle(
          title: 'ECCD GrowthTrack',
          subtitle: 'TEACHER WORKSPACE',
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final confirmed = await ConfirmationDialog.show(
                context: context,
                title: 'Logout',
                message: 'Are you sure you want to logout from ECCD GrowthTrack?',
                confirmLabel: 'Logout',
                confirmColor: Colors.red,
                icon: Icons.logout,
              );
              if (!confirmed) return;
              await AuthRepositoryImpl().logout();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth < 520 ? 1 : 2;
          if (constraints.maxWidth > 900) {
            crossAxisCount = 4;
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 3;
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EccdSectionIntro(
                  title: 'Your classroom at a glance',
                  subtitle: 'Track attendance, development, and meaningful learning moments in one place.',
                  icon: Icons.school_rounded,
                ),
                const SizedBox(height: 22),
                Text(
                  'Workspace modules',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    // Compact horizontal cards stay readable without vertical
                    // overflow across phone, tablet, and desktop widths.
                    childAspectRatio: constraints.maxWidth > 900 ? 1.15 : 1.45,
                    children: [
              _DashboardCard(
                title: 'Register Child',
                description: 'Create and link a child profile to a parent.',
                actionLabel: 'Register child',
                icon: Icons.person_add,
                color: BrandColors.sky,
                onTap: () => Navigator.pushNamed(context, '/register-child'),
              ),
              _DashboardCard(
                title: 'Attendance',
                description: 'Record and review today\'s class attendance.',
                actionLabel: 'Mark attendance',
                icon: Icons.calendar_today,
                color: BrandColors.green,
                onTap: () => Navigator.pushNamed(context, '/attendance'),
              ),
              _DashboardCard(
                title: 'ECCD Evaluation',
                description: 'Record development assessment results.',
                actionLabel: 'Start evaluation',
                icon: Icons.assignment,
                color: BrandColors.sunshine,
                onTap: () => Navigator.pushNamed(context, '/eccd-evaluation'),
              ),
              _DashboardCard(
                title: 'Home Activities',
                description: 'Assign activities and review parent submissions.',
                actionLabel: 'Manage activities',
                icon: Icons.home_work,
                color: BrandColors.navy,
                onTap: () => Navigator.pushNamed(context, '/home-activities'),
              ),
              _DashboardCard(
                title: 'Referrals',
                description: 'Create and monitor child referral records.',
                actionLabel: 'Manage referrals',
                icon: Icons.medical_services,
                color: const Color(0xFFE76F51),
                onTap: () => Navigator.pushNamed(context, '/referrals'),
              ),
              _DashboardCard(
                title: 'Reports',
                description: 'View classroom and child development reports.',
                actionLabel: 'View reports',
                icon: Icons.bar_chart,
                color: BrandColors.green,
                onTap: () => Navigator.pushNamed(context, '/reports'),
              ),
              _DashboardCard(
                title: 'Triangulation',
                description: 'Compare teacher, parent, and record insights.',
                actionLabel: 'Review insights',
                icon: Icons.analytics,
                color: BrandColors.sky,
                onTap: () => Navigator.pushNamed(context, '/triangulation'),
              ),
              _DashboardCard(
                title: 'AI Summary',
                description: 'Generate a development summary for review.',
                actionLabel: 'Generate summary',
                icon: Icons.auto_awesome,
                color: BrandColors.navy,
                onTap: () => Navigator.pushNamed(context, '/ai-summary'),
              ),
              _DashboardCard(
                title: 'Clarification Requests',
                description: 'Read and respond to parent questions.',
                actionLabel: 'Respond to requests',
                icon: Icons.question_answer,
                color: BrandColors.green,
                onTap: () => Navigator.pushNamed(context, '/teacher/clarifications'),
              ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(24),
      ),
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 27, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.25, color: colors.onSurfaceVariant)),
                    const SizedBox(height: 7),
                    Text(actionLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
