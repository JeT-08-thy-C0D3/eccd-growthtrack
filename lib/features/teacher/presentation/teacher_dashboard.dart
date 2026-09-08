import 'package:flutter/material.dart';
import '../../auth/data/auth_repository_impl.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthRepositoryImpl().logout();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Adjust columns based on screen width
          int crossAxisCount = 2;
          if (constraints.maxWidth > 900) {
            crossAxisCount = 4;
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 3;
          }

          return GridView.count(
            crossAxisCount: crossAxisCount,
            padding: const EdgeInsets.all(24),
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            children: [
              _DashboardCard(
                title: 'Register Child',
                icon: Icons.person_add,
                color: Colors.blue,
                onTap: () => Navigator.pushNamed(context, '/register-child'),
              ),
              _DashboardCard(
                title: 'Attendance',
                icon: Icons.calendar_today,
                color: Colors.green,
                onTap: () => Navigator.pushNamed(context, '/attendance'),
              ),
              _DashboardCard(
                title: 'ECCD Evaluation',
                icon: Icons.assignment,
                color: Colors.orange,
                onTap: () => Navigator.pushNamed(context, '/eccd-evaluation'),
              ),
              _DashboardCard(
                title: 'Home Activities',
                icon: Icons.home_work,
                color: Colors.purple,
                onTap: () => Navigator.pushNamed(context, '/home-activities'),
              ),
              _DashboardCard(
                title: 'Referrals',
                icon: Icons.medical_services,
                color: Colors.red,
                onTap: () => Navigator.pushNamed(context, '/referrals'),
              ),
              _DashboardCard(
                title: 'Reports',
                icon: Icons.bar_chart,
                color: Colors.teal,
                onTap: () => Navigator.pushNamed(context, '/reports'),
              ),
              _DashboardCard(
                title: 'Triangulation',
                icon: Icons.analytics,
                color: Colors.indigo,
                onTap: () => Navigator.pushNamed(context, '/triangulation'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
