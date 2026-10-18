import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/domain/reports_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import 'admin_reports_page.dart';
import 'audit_trail_page.dart';
import 'child_monitoring_page.dart';
import 'referral_monitoring_page.dart';
import 'system_settings_page.dart';
import 'user_management_page.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final ReportsRepository _reportsRepository = ReportsRepositoryImpl();
  DashboardStats? _stats;
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await _reportsRepository.getDashboardStats();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  void _logout() async {
    await AuthRepositoryImpl().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const EccdAppBarTitle(
          title: 'ECCD GrowthTrack',
          subtitle: 'MSWD ADMIN PORTAL',
        ),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: colorScheme.outlineVariant, width: 1)),
        actions: [
          _ProfileMenu(
            onLogout: _logout,
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: !isDesktop ? Drawer(child: _buildDrawerItems(context)) : null,
      body: Row(
        children: [
          if (isDesktop) 
            Container(
              width: 280,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: colorScheme.outlineVariant, width: 1)),
              ),
              child: _buildDrawerItems(context),
            ),
          Expanded(
            child: _buildSelectedPage(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPage(BuildContext context) {
    switch (_selectedIndex) {
      case 1:
        return const UserManagementPage();
      case 2:
        return const ChildMonitoringPage();
      case 3:
        return const ReferralMonitoringPage();
      case 4:
        return const AdminReportsPage();
      case 5:
        return const AuditTrailPage();
      case 6:
        return const SystemSettingsPage();
      case 0:
      default:
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final colorScheme = Theme.of(context).colorScheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Municipal Overview',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                      ),
                      Text(
                        'Real-time data from all barangays and centers',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildStatsGrid(),
              const SizedBox(height: 48),
              Text(
                'Quick Access Modules',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildQuickActions(context),
            ],
          ),
        );
    }
  }

  void _selectSection(int index) {
    setState(() => _selectedIndex = index);
    if (MediaQuery.of(context).size.width <= 900 && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _buildDrawerItems(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const EccdLogo(width: 42, height: 42),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'GrowthTrack Admin',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _DrawerTile(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Dashboard',
          isSelected: _selectedIndex == 0,
          onTap: () => _selectSection(0),
        ),
        _DrawerTile(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'User Management',
          isSelected: _selectedIndex == 1,
          onTap: () => _selectSection(1),
        ),
        _DrawerTile(
          icon: Icons.child_care_outlined,
          selectedIcon: Icons.child_care,
          label: 'Child Monitoring',
          isSelected: _selectedIndex == 2,
          onTap: () => _selectSection(2),
        ),
        _DrawerTile(
          icon: Icons.assignment_late_outlined,
          selectedIcon: Icons.assignment_late,
          label: 'Referrals',
          isSelected: _selectedIndex == 3,
          onTap: () => _selectSection(3),
        ),
        _DrawerTile(
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          label: 'Reports & Analytics',
          isSelected: _selectedIndex == 4,
          onTap: () => _selectSection(4),
        ),
        _DrawerTile(
          icon: Icons.history_outlined,
          selectedIcon: Icons.history,
          label: 'System Audit Trail',
          isSelected: _selectedIndex == 5,
          onTap: () => _selectSection(5),
        ),
        const Spacer(),
        const Divider(indent: 16, endIndent: 16),
        _DrawerTile(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          label: 'System Settings',
          isSelected: _selectedIndex == 6,
          onTap: () => _selectSection(6),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatsGrid() {
    int crossAxisCount = 1;
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) {
      crossAxisCount = 5;
    } else if (width > 800) {
      crossAxisCount = 3;
    } else if (width > 600) {
      crossAxisCount = 2;
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          title: 'Total Teachers',
          value: _stats?.totalTeachers.toString() ?? '0',
          icon: Icons.school,
          color: BrandColors.sky,
        ),
        _StatCard(
          title: 'Total Parents',
          value: _stats?.totalParents.toString() ?? '0',
          icon: Icons.family_restroom,
          color: BrandColors.sunshine,
        ),
        _StatCard(
          title: 'Total Children',
          value: _stats?.totalChildren.toString() ?? '0',
          icon: Icons.child_care,
          color: BrandColors.green,
          onTap: () => _selectSection(2),
        ),
        _StatCard(
          title: 'Pending Referrals',
          value: _stats?.pendingReferrals.toString() ?? '0',
          icon: Icons.assignment_late,
          color: const Color(0xFFE76F51),
          onTap: () => _selectSection(3),
        ),
        _StatCard(
          title: 'Evaluations',
          value: _stats?.completedEvaluations.toString() ?? '0',
          icon: Icons.check_circle,
          color: BrandColors.navy,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _QuickActionCard(
          title: 'Add User',
          subtitle: 'Create Center Staff Accounts',
          icon: Icons.person_add_alt_1,
          color: BrandColors.sky,
          onTap: () => _selectSection(1),
        ),
        _QuickActionCard(
          title: 'Case Review',
          subtitle: 'Check Pending Referrals',
          icon: Icons.assignment_turned_in,
          color: const Color(0xFFE76F51),
          onTap: () => _selectSection(3),
        ),
        _QuickActionCard(
          title: 'Audit Logs',
          subtitle: 'Review System Activity',
          icon: Icons.security,
          color: BrandColors.navy,
          onTap: () => _selectSection(5),
        ),
      ],
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2),
      child: ListTile(
        leading: Icon(isSelected ? selectedIcon : icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  final VoidCallback onLogout;

  const _ProfileMenu({required this.onLogout});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout from ECCD GrowthTrack?',
      confirmLabel: 'Logout',
      confirmColor: Colors.red,
      icon: Icons.logout,
    );
    if (confirmed) onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      onSelected: (value) {
        if (value == 'logout') _confirmLogout(context);
      },
      child: const CircleAvatar(
        radius: 18,
        backgroundColor: BrandColors.navy,
        child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
