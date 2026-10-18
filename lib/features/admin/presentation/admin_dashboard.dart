import 'package:flutter/material.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin/MSWD Dashboard'),
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
      body: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(24),
        children: [
          _AdminCard(
            title: 'User Management',
            icon: Icons.people,
            color: Colors.blue,
            onTap: () => Navigator.pushNamed(context, '/admin/users'),
          ),
          _AdminCard(
            title: 'Referral Monitoring',
            icon: Icons.assignment_late,
            color: Colors.orange,
            onTap: () => Navigator.pushNamed(context, '/referrals'),
          ),
          _AdminCard(
            title: 'Reports & Analytics',
            icon: Icons.bar_chart,
            color: Colors.teal,
            onTap: () => Navigator.pushNamed(context, '/reports'),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AdminCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
