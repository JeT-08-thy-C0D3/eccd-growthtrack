import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../auth/data/auth_repository_impl.dart';
import '../../attendance/presentation/attendance_page.dart';
import '../../child_profile/presentation/child_list_page.dart';
import '../../eccd_evaluation/presentation/evaluation_page.dart';
import '../../home_activities/presentation/activity_management_page.dart';
import '../../referral/presentation/referral_page.dart';
import '../../reports/presentation/reports_page.dart';
import 'teacher_clarifications_page.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/role_web_sidebar.dart';
import '../../../core/database/database_helper.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _selectedSection = 0;
  int _childCount = 0;
  bool _isLoadingClassroom = true;
  bool _isMoreOpen = false;

  @override
  void initState() {
    super.initState();
    _loadClassroomCount();
  }

  Future<void> _loadClassroomCount() async {
    final uid = AuthRepositoryImpl().firebaseUserId;
    if (uid == null) return;

    final cached = await DatabaseHelper.instance.readChildrenByTeacher(
      uid,
      allowCloudFallback: false,
    );
    if (!mounted) return;
    setState(() {
      _childCount = cached.length;
      _isLoadingClassroom = false;
    });

    // Fetch/cache cloud records after the local count is already visible.
    unawaited(() async {
      final refreshed = await DatabaseHelper.instance.readChildrenByTeacher(
        uid,
      );
      if (!mounted) return;
      setState(() => _childCount = refreshed.length);
    }());
  }

  void _selectSection(int index) => setState(() => _selectedSection = index);

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

  void _showMoreSections() => setState(() => _isMoreOpen = !_isMoreOpen);

  void _selectMoreSection(int index) {
    setState(() {
      _selectedSection = index;
      _isMoreOpen = false;
    });
  }

  Widget _moreNavigationTile(String label, IconData icon, int index) =>
      ListTile(
        leading: Icon(icon, color: BrandColors.navy),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _selectMoreSection(index),
      );

  Widget _buildSelectedSection() {
    switch (_selectedSection) {
      case 1:
        return const ChildListPage();
      case 2:
        return const AttendancePage();
      case 3:
        return const EvaluationPage();
      case 4:
        return const ActivityManagementPage();
      case 5:
        return const ReferralPage();
      case 6:
        return const TeacherClarificationsPage();
      default:
        return const ReportsPage(embedded: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
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
            if (kIsWeb && MediaQuery.sizeOf(context).width > 900)
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: _logout,
              ),
          ],
        ),
        bottomNavigationBar: kIsWeb && MediaQuery.sizeOf(context).width > 900
            ? null
            : SafeArea(
                top: false,
                child: NavigationBar(
                  selectedIndex: _selectedSection <= 2 ? _selectedSection : 3,
                  onDestinationSelected: (index) {
                    if (index == 3) {
                      _showMoreSections();
                    } else {
                      setState(() => _isMoreOpen = false);
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
                      icon: Icon(Icons.groups_outlined),
                      selectedIcon: Icon(Icons.groups),
                      label: 'Children',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_today_outlined),
                      selectedIcon: Icon(Icons.calendar_today),
                      label: 'Attendance',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.more_horiz),
                      selectedIcon: Icon(Icons.more_horiz),
                      label: 'More',
                    ),
                  ],
                ),
              ),
        body: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final dashboard = _TeacherWorkspaceHome(
                  childCount: _childCount,
                  isLoading: _isLoadingClassroom,
                  onNavigate: _selectSection,
                );
                /*final dashboard = Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EccdSectionIntro(
                    title: 'Your classroom at a glance',
                    subtitle: 'Track attendance, development, and meaningful learning moments in one place.',
                    icon: Icons.school_rounded,
                  ),
                  const SizedBox(height: 14),
                  Card(
                    color: BrandColors.sky.withValues(alpha: .08),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            color: BrandColors.navy,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isLoadingClassroom
                                  ? 'Loading saved classroom data...'
                                  : '$_childCount child${_childCount == 1 ? '' : 'ren'} assigned to your classroom',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    kIsWeb && constraints.maxWidth > 900
                        ? 'Classroom overview'
                        : 'Workspace modules',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: kIsWeb && constraints.maxWidth > 900
                        ? GridView.count(
                            crossAxisCount: 3,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            childAspectRatio: 1.55,
                            children: [
                              _TeacherOverviewCard(
                                title: 'Daily attendance',
                                detail: _childCount == 0
                                    ? 'No saved children yet. Cloud data will appear once linked.'
                                    : 'Ready for $_childCount assigned child${_childCount == 1 ? '' : 'ren'}.',
                                icon: Icons.fact_check_outlined,
                                color: BrandColors.green,
                              ),
                              _TeacherOverviewCard(
                                title: 'Development records',
                                detail: 'Keep evaluations current so every child\'s progress is visible.',
                                icon: Icons.auto_graph_outlined,
                                color: BrandColors.sky,
                              ),
                              _TeacherOverviewCard(
                                title: 'Family engagement',
                                detail: 'Review home activity submissions and parent questions.',
                                icon: Icons.family_restroom_outlined,
                                color: BrandColors.sunshine,
                              ),
                            ],
                          )
                        : GridView.count(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            // Compact horizontal cards stay readable without vertical
                            // overflow across phone, tablet, and desktop widths.
                            childAspectRatio: constraints.maxWidth > 900
                                ? 1.15
                                : 1.45,
                            children: [
                              _DashboardCard(
                                title: 'Register Child',
                                description: 'Create and link a child profile to a parent.',
                                actionLabel: 'Register child',
                                icon: Icons.person_add,
                                color: BrandColors.sky,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/register-child',
                                ),
                              ),
                              _DashboardCard(
                                title: 'Attendance',
                                description: 'Record and review today\'s class attendance.',
                                actionLabel: 'Mark attendance',
                                icon: Icons.calendar_today,
                                color: BrandColors.green,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/attendance'),
                              ),
                              _DashboardCard(
                                title: 'ECCD Evaluation',
                                description:
                                    'Record development assessment results.',
                                actionLabel: 'Start evaluation',
                                icon: Icons.assignment,
                                color: BrandColors.sunshine,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/eccd-evaluation',
                                ),
                              ),
                              _DashboardCard(
                                title: 'Home Activities',
                                description: 'Assign activities and review parent submissions.',
                                actionLabel: 'Manage activities',
                                icon: Icons.home_work,
                                color: BrandColors.navy,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/home-activities',
                                ),
                              ),
                              _DashboardCard(
                                title: 'Referrals',
                                description: 'Create and monitor child referral records.',
                                actionLabel: 'Manage referrals',
                                icon: Icons.medical_services,
                                color: const Color(0xFFE76F51),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/referrals'),
                              ),
                              _DashboardCard(
                                title: 'Triangulation',
                                description: 'Compare teacher, parent, and record insights.',
                                actionLabel: 'Review insights',
                                icon: Icons.analytics,
                                color: BrandColors.sky,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/triangulation',
                                ),
                              ),
                              _DashboardCard(
                                title: 'AI Summary',
                                description: 'Generate a development summary for review.',
                                actionLabel: 'Generate summary',
                                icon: Icons.auto_awesome,
                                color: BrandColors.navy,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/ai-summary'),
                              ),
                              _DashboardCard(
                                title: 'Clarification Requests',
                                description:
                                    'Read and respond to parent questions.',
                                actionLabel: 'Respond to requests',
                                icon: Icons.question_answer,
                                color: BrandColors.green,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/teacher/clarifications',
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );*/

                if (kIsWeb && constraints.maxWidth > 900) {
                  return Row(
                    children: [
                      RoleWebSidebar(
                        title: 'Teacher Workspace',
                        subtitle: 'CLASSROOM PORTAL',
                        showIdentityLogo: false,
                        items: [
                          RoleWebNavItem(
                            label: 'Dashboard',
                            icon: Icons.dashboard_outlined,
                            selected: _selectedSection == 0,
                            onTap: () => _selectSection(0),
                          ),
                          RoleWebNavItem(
                            label: 'Register Child',
                            icon: Icons.person_add_outlined,
                            selected: _selectedSection == 1,
                            onTap: () => _selectSection(1),
                          ),
                          RoleWebNavItem(
                            label: 'Attendance',
                            icon: Icons.calendar_today_outlined,
                            selected: _selectedSection == 2,
                            onTap: () => _selectSection(2),
                          ),
                          RoleWebNavItem(
                            label: 'ECCD Evaluation',
                            icon: Icons.assignment_outlined,
                            selected: _selectedSection == 3,
                            onTap: () => _selectSection(3),
                          ),
                          RoleWebNavItem(
                            label: 'Home Activities',
                            icon: Icons.home_work_outlined,
                            selected: _selectedSection == 4,
                            onTap: () => _selectSection(4),
                          ),
                          RoleWebNavItem(
                            label: 'Referrals',
                            icon: Icons.medical_services_outlined,
                            selected: _selectedSection == 5,
                            onTap: () => _selectSection(5),
                          ),
                          RoleWebNavItem(
                            label: 'Clarifications',
                            icon: Icons.question_answer_outlined,
                            selected: _selectedSection == 6,
                            onTap: () => _selectSection(6),
                          ),
                        ],
                      ),
                      Expanded(
                        child: _selectedSection == 0
                            ? dashboard
                            : _buildSelectedSection(),
                      ),
                    ],
                  );
                }
                return _selectedSection == 0
                    ? dashboard
                    : _buildSelectedSection();
              },
            ),
            if (_isMoreOpen &&
                !(kIsWeb && MediaQuery.sizeOf(context).width > 900))
              Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  elevation: 10,
                  color: Theme.of(context).colorScheme.surface,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _moreNavigationTile(
                          'Evaluation',
                          Icons.assignment_outlined,
                          3,
                        ),
                        _moreNavigationTile(
                          'Home activities',
                          Icons.home_work_outlined,
                          4,
                        ),
                        _moreNavigationTile(
                          'Referrals',
                          Icons.medical_services_outlined,
                          5,
                        ),
                        _moreNavigationTile(
                          'Clarifications',
                          Icons.question_answer_outlined,
                          6,
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () {
                            setState(() => _isMoreOpen = false);
                            _logout();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TeacherWorkspaceHome extends StatelessWidget {
  const _TeacherWorkspaceHome({
    required this.childCount,
    required this.isLoading,
    required this.onNavigate,
  });

  final int childCount;
  final bool isLoading;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final columns = constraints.maxWidth >= 1050 ? 3 : (isPhone ? 1 : 2);
        final horizontalPadding = isPhone ? 16.0 : 32.0;
        final contentWidth = constraints.maxWidth - (horizontalPadding * 2);
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
                Container(
                  width: double.infinity,
                  height: isPhone ? 208 : 224,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEAF7FF), Color(0xFFF8FCFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  clipBehavior: Clip.antiAlias,
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
                        right: isPhone
                            ? 24
                            : constraints.maxWidth < 780
                            ? 28
                            : constraints.maxWidth * .47,
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
                              'Teacher Workspace',
                              style: TextStyle(
                                color: Color(0xFF102A72),
                                fontSize: isPhone ? 28 : 34,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 9),
                            const Text(
                              'Keep your classroom organized and every child\'s progress visible.',
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
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _TeacherMetric(
                      label: 'Assigned children',
                      value: isLoading ? '—' : '$childCount',
                      icon: Icons.groups_rounded,
                      color: BrandColors.green,
                      width: isPhone ? contentWidth : 296,
                    ),
                    _TeacherMetric(
                      label: 'Attendance',
                      value: 'Ready',
                      icon: Icons.fact_check_rounded,
                      color: BrandColors.sky,
                      width: isPhone ? contentWidth : 296,
                    ),
                    _TeacherMetric(
                      label: 'Evaluations',
                      value: 'Review',
                      icon: Icons.auto_graph_rounded,
                      color: BrandColors.sunshine,
                      width: isPhone ? contentWidth : 296,
                    ),
                    _TeacherMetric(
                      label: 'Referrals',
                      value: '0',
                      icon: Icons.medical_services_rounded,
                      color: Color(0xFFE76F51),
                      width: isPhone ? contentWidth : 296,
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
                    _WorkspaceAction(
                      title: 'Register a child',
                      subtitle: 'Create a new child profile and add to your classroom.',
                      actionLabel: 'Register Child',
                      icon: Icons.person_add_alt_1_rounded,
                      color: BrandColors.sky,
                      onTap: () => onNavigate(1),
                    ),
                    _WorkspaceAction(
                      title: 'Take attendance',
                      subtitle: 'Record today\'s classroom attendance',
                      actionLabel: 'Take Attendance',
                      icon: Icons.calendar_month_rounded,
                      color: BrandColors.green,
                      onTap: () => onNavigate(2),
                    ),
                    _WorkspaceAction(
                      title: 'Start evaluation',
                      subtitle:
                          'Update and record a child\'s development progress.',
                      actionLabel: 'Start Evaluation',
                      icon: Icons.assignment_turned_in_rounded,
                      color: BrandColors.sunshine,
                      onTap: () => onNavigate(3),
                    ),
                    _WorkspaceAction(
                      title: 'Home activities',
                      subtitle: 'Send and manage home learning activities.',
                      actionLabel: 'Manage Home Activities',
                      icon: Icons.home_work_rounded,
                      color: BrandColors.navy,
                      onTap: () => onNavigate(4),
                    ),
                    _WorkspaceAction(
                      title: 'Referrals',
                      subtitle: 'Create and track child referrals to support services.',
                      actionLabel: 'Manage Referrals',
                      icon: Icons.medical_services_rounded,
                      color: const Color(0xFFE76F51),
                      onTap: () => onNavigate(5),
                    ),
                    _WorkspaceAction(
                      title: 'Clarifications',
                      subtitle: 'Respond to parent questions',
                      actionLabel: 'Send Clarification',
                      icon: Icons.forum_rounded,
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

class _TeacherMetric extends StatelessWidget {
  const _TeacherMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
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

class _WorkspaceAction extends StatelessWidget {
  const _WorkspaceAction({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                const Spacer(),
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F8FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: BrandColors.sky,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF07135B),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TeacherOverviewCard extends StatelessWidget {
  const _TeacherOverviewCard({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: .06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: color.withValues(alpha: .18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
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
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
