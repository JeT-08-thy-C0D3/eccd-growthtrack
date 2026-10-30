import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../auth/data/auth_repository_impl.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/domain/reports_model.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/role_web_sidebar.dart';
import 'admin_reports_page.dart';
import 'audit_trail_page.dart';
import 'child_monitoring_page.dart';
import 'referral_monitoring_page.dart';
import 'system_settings_page.dart';
import 'user_management_page.dart';

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
    try {
      final stats = await _reportsRepository.getDashboardStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to log out from ECCD GrowthTrack?',
      confirmLabel: 'Logout',
      confirmColor: Colors.red,
      icon: Icons.logout,
    );
    if (!confirmed) return;
    await AuthRepositoryImpl().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _selectSection(int index) => setState(() => _selectedIndex = index);

  void _showMoreSections() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _moreSectionTile(
              'Referrals',
              Icons.medical_information_outlined,
              3,
            ),
            _moreSectionTile('Audit trail', Icons.manage_search_outlined, 4),
            _moreSectionTile('Reports', Icons.bar_chart_rounded, 5),
            _moreSectionTile('Settings', Icons.settings_outlined, 6),
          ],
        ),
      ),
    );
  }

  Widget _moreSectionTile(String label, IconData icon, int index) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    selected: _selectedIndex == index,
    onTap: () {
      Navigator.pop(context);
      _selectSection(index);
    },
  );

  Widget _buildSelectedSection() {
    switch (_selectedIndex) {
      case 1:
        return const UserManagementPage();
      case 2:
        return const ChildMonitoringPage();
      case 3:
        return const ReferralMonitoringPage();
      case 4:
        return const AuditTrailPage();
      case 5:
        return const AdminReportsPage();
      case 6:
        return const SystemSettingsPage();
      default:
        return _AdminWorkspaceHome(
          stats: _stats,
          isLoading: _isLoading,
          onNavigate: _selectSection,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const EccdAppBarTitle(
            title: 'ECCD GrowthTrack',
            subtitle: 'MSWD ADMIN PORTAL',
          ),
          backgroundColor: colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
            const SizedBox(width: 12),
          ],
        ),
        bottomNavigationBar: kIsWeb && MediaQuery.sizeOf(context).width > 900
            ? null
            : NavigationBar(
                selectedIndex: _selectedIndex <= 2 ? _selectedIndex : 3,
                onDestinationSelected: (index) {
                  if (index == 3) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _showMoreSections();
                    });
                  } else {
                    _selectSection(index);
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.group_outlined),
                    selectedIcon: Icon(Icons.group),
                    label: 'Users',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.child_care_outlined),
                    selectedIcon: Icon(Icons.child_care),
                    label: 'Children',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    selectedIcon: Icon(Icons.more_horiz),
                    label: 'More',
                  ),
                ],
              ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (kIsWeb && constraints.maxWidth > 900) {
              return Row(
                children: [
                  RoleWebSidebar(
                    title: 'Admin Workspace',
                    subtitle: 'MSWD ADMIN PORTAL',
                    showIdentityLogo: false,
                    items: [
                      RoleWebNavItem(
                        label: 'Dashboard',
                        icon: Icons.dashboard_outlined,
                        selected: _selectedIndex == 0,
                        onTap: () => _selectSection(0),
                      ),
                      RoleWebNavItem(
                        label: 'User Management',
                        icon: Icons.group_outlined,
                        selected: _selectedIndex == 1,
                        onTap: () => _selectSection(1),
                      ),
                      RoleWebNavItem(
                        label: 'Child Monitoring',
                        icon: Icons.child_care_outlined,
                        selected: _selectedIndex == 2,
                        onTap: () => _selectSection(2),
                      ),
                      RoleWebNavItem(
                        label: 'Referrals',
                        icon: Icons.medical_information_outlined,
                        selected: _selectedIndex == 3,
                        onTap: () => _selectSection(3),
                      ),
                      RoleWebNavItem(
                        label: 'Audit Trail',
                        icon: Icons.manage_search_outlined,
                        selected: _selectedIndex == 4,
                        onTap: () => _selectSection(4),
                      ),
                      RoleWebNavItem(
                        label: 'Reports',
                        icon: Icons.bar_chart_rounded,
                        selected: _selectedIndex == 5,
                        onTap: () => _selectSection(5),
                      ),
                      RoleWebNavItem(
                        label: 'Settings',
                        icon: Icons.settings_outlined,
                        selected: _selectedIndex == 6,
                        onTap: () => _selectSection(6),
                      ),
                    ],
                  ),
                  Expanded(child: _buildSelectedSection()),
                ],
              );
            }
            return _buildSelectedSection();
          },
        ),
      ),
    );
  }
}

class _AdminWorkspaceHome extends StatelessWidget {
  const _AdminWorkspaceHome({
    required this.stats,
    required this.isLoading,
    required this.onNavigate,
  });

  final DashboardStats? stats;
  final bool isLoading;
  final ValueChanged<int> onNavigate;

  String _value(int value) => isLoading ? '—' : '$value';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final columns = constraints.maxWidth >= 1050 ? 3 : (isPhone ? 1 : 2);
        final horizontalPadding = isPhone ? 16.0 : 32.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminHero(
                  compact: constraints.maxWidth < 780,
                  isPhone: isPhone,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _AdminMetric(
                      label: 'Active teachers',
                      value: _value(stats?.totalTeachers ?? 0),
                      icon: Icons.school_rounded,
                      color: BrandColors.sky,
                    ),
                    _AdminMetric(
                      label: 'Registered children',
                      value: _value(stats?.totalChildren ?? 0),
                      icon: Icons.groups_rounded,
                      color: BrandColors.green,
                    ),
                    _AdminMetric(
                      label: 'Pending referrals',
                      value: _value(stats?.pendingReferrals ?? 0),
                      icon: Icons.assignment_late_rounded,
                      color: const Color(0xFFE76F51),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Quick actions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: constraints.maxWidth >= 800
                      ? 1.7
                      : (isPhone ? 1.55 : 1.3),
                  children: [
                    _AdminAction(
                      title: 'Manage users',
                      subtitle: 'Create and manage staff accounts',
                      icon: Icons.person_add_alt_1_rounded,
                      color: BrandColors.sky,
                      onTap: () => onNavigate(1),
                    ),
                    _AdminAction(
                      title: 'Monitor children',
                      subtitle: 'Review child records and progress',
                      icon: Icons.child_friendly_rounded,
                      color: BrandColors.green,
                      onTap: () => onNavigate(2),
                    ),
                    _AdminAction(
                      title: 'Review referrals',
                      subtitle: 'Prioritize support cases',
                      icon: Icons.medical_services_rounded,
                      color: const Color(0xFFE76F51),
                      onTap: () => onNavigate(3),
                    ),
                    _AdminAction(
                      title: 'Audit trail',
                      subtitle: 'Review system activity securely',
                      icon: Icons.verified_user_rounded,
                      color: BrandColors.navy,
                      onTap: () => onNavigate(4),
                    ),
                    _AdminAction(
                      title: 'View reports',
                      subtitle: 'See program data and insights',
                      icon: Icons.auto_graph_rounded,
                      color: BrandColors.sunshine,
                      onTap: () => onNavigate(5),
                    ),
                    _AdminAction(
                      title: 'System settings',
                      subtitle: 'Manage portal preferences',
                      icon: Icons.settings_suggest_rounded,
                      color: BrandColors.green,
                      onTap: () => onNavigate(6),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({required this.compact, required this.isPhone});
  final bool compact;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: isPhone ? 208 : 224,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF7FF), Color(0xFFF8FCFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: isPhone ? 1 : .46,
                heightFactor: 1,
                child: Image.asset(
                  'assets/images/teacher_workspace_hero.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          if (isPhone)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xE6EAF7FF), Color(0x66F8FCFF)],
                  ),
                ),
              ),
            ),
          Positioned(
            left: isPhone ? 22 : 36,
            top: isPhone ? 28 : 38,
            right: isPhone ? 24 : (compact ? 28 : 410),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WELCOME TO',
                  style: TextStyle(
                    color: Color(0xFF4B83B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Admin Workspace',
                  style: TextStyle(
                    color: Color(0xFF102A72),
                    fontSize: isPhone ? 28 : 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Keep program operations, users, and child support data organized in one place.',
                  style: TextStyle(
                    color: Color(0xFF54769B),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 210,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: .18)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AdminAction extends StatelessWidget {
  const _AdminAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
