import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../auth/data/auth_repository_impl.dart';
import '../../attendance/presentation/attendance_page.dart';
import '../../child_profile/presentation/child_list_page.dart';
import '../../eccd_evaluation/presentation/evaluation_page.dart';
import '../../home_activities/data/activity_repository.dart';
import '../../home_activities/domain/activity_model.dart';
import '../../home_activities/domain/activity_submission_model.dart';
import '../../home_activities/presentation/activity_management_page.dart';
import '../../referral/presentation/referral_page.dart';
import '../../reports/presentation/reports_page.dart';
import 'teacher_clarifications_page.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/role_web_sidebar.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _selectedSection = 0;
  int _childCount = 0;
  bool _isLoadingClassroom = true;
  bool _isLoadingActivityAnalytics = true;
  bool _isMoreOpen = false;
  final ActivityRepository _activityRepository = ActivityRepositoryImpl();
  List<_ChildActivityAnalytics> _activityAnalytics = const [];
  List<ChildModel> _assignedChildren = const [];
  UserModel? _loggedInTeacher;

  @override
  void initState() {
    super.initState();
    _loadClassroomCount();
  }

  Future<void> _loadClassroomCount() async {
    final authRepository = AuthRepositoryImpl();
    final teacher = await authRepository.getCurrentUser();
    final uid = teacher?.uid.trim().isNotEmpty == true
        ? teacher!.uid
        : authRepository.firebaseUserId;
    if (uid == null || uid.trim().isEmpty) {
      if (mounted) setState(() => _isLoadingClassroom = false);
      return;
    }

    if (teacher?.role == UserRole.teacher) {
      final repaired = await DatabaseHelper.instance
          .repairLegacyTeacherAssignments(
            teacherUid: uid,
            teacherName: teacher!.name,
          );
      if (repaired > 0) unawaited(SyncService().performSync());
    }

    final cached = await DatabaseHelper.instance.readChildrenByTeacher(
      uid,
      allowCloudFallback: false,
    );
    if (!mounted) return;
    setState(() {
      _loggedInTeacher = teacher;
      _assignedChildren = cached;
      _childCount = cached.length;
      _isLoadingClassroom = false;
    });
    unawaited(_loadActivityAnalytics(cached));

    // Fetch/cache cloud records after the local count is already visible.
    unawaited(() async {
      final refreshed = await DatabaseHelper.instance.readChildrenByTeacher(
        uid,
      );
      if (!mounted) return;
      setState(() {
        _assignedChildren = refreshed;
        _childCount = refreshed.length;
      });
      await _loadActivityAnalytics(refreshed);
    }());
  }

  Future<void> _loadActivityAnalytics(List<ChildModel> children) async {
    if (mounted) setState(() => _isLoadingActivityAnalytics = true);
    try {
      final childIds = children.map((child) => child.childId).toSet();
      List<ActivityModel> activities;
      List<ActivitySubmissionModel> submissions;

      if (kIsWeb) {
        final teacherUid = _loggedInTeacher?.uid.trim().isNotEmpty == true
            ? _loggedInTeacher!.uid
            : AuthRepositoryImpl().firebaseUserId;
        if (teacherUid == null || teacherUid.trim().isEmpty) {
          throw StateError('The teacher session is not available.');
        }

        // Firestore rules only allow a teacher to read activities assigned to
        // their account. A collection-wide read is rejected by those rules,
        // which previously made every dashboard card fall back to zero.
        // Keep the two sources independent so one temporary failure never
        // hides valid activity progress from the other source.
        activities = const [];
        submissions = const [];
        try {
          final activitySnapshot = await FirebaseFirestore.instance
              .collection('activities')
              .where('assigned_teacher_uid', isEqualTo: teacherUid)
              .get(const GetOptions(source: Source.server));
          activities = activitySnapshot.docs
              .map(
                (doc) => ActivityModel.fromMap({
                  ...doc.data(),
                  'id': doc.data()['id'] ?? int.tryParse(doc.id),
                }),
              )
              .where((activity) => childIds.contains(activity.childId))
              .toList();
        } catch (_) {}
        try {
          final submissionSnapshot = await FirebaseFirestore.instance
              .collection('activity_submissions')
              .where('teacher_uid', isEqualTo: teacherUid)
              .get(const GetOptions(source: Source.server));
          submissions = submissionSnapshot.docs
              .map(
                (doc) => ActivitySubmissionModel.fromMap({
                  ...doc.data(),
                  'id': doc.data()['id'] ?? int.tryParse(doc.id),
                }),
              )
              .where((submission) => childIds.contains(submission.childId))
              .toList();
        } catch (_) {}
      } else {
        activities = (await _activityRepository.getAllActivities())
            .where((activity) => childIds.contains(activity.childId))
            .toList();
        submissions = (await _activityRepository.getAllSubmissions())
            .map(ActivitySubmissionModel.fromMap)
            .toList();
      }

      final activitiesById = {
        for (final activity in activities)
          if (activity.id != null) activity.id!: activity,
      };
      final analytics = children.map((child) {
        final childActivities = activities
            .where((activity) => activity.childId == child.childId)
            .toList();
        final childActivityIds = childActivities
            .map((activity) => activity.id)
            .whereType<int>()
            .toSet();
        final childSubmissions = submissions
            .where(
              (submission) => childActivityIds.contains(submission.activityId),
            )
            .toList();
        final scoredSubmissions = childSubmissions
            .where(
              (submission) =>
                  submission.score != null &&
                  (activitiesById[submission.activityId]?.maxScore ?? 0) > 0,
            )
            .toList();
        final averageScore = scoredSubmissions.isEmpty
            ? null
            : scoredSubmissions
                      .map(
                        (submission) =>
                            submission.score! /
                            activitiesById[submission.activityId]!.maxScore,
                      )
                      .reduce((total, score) => total + score) /
                  scoredSubmissions.length;

        return _ChildActivityAnalytics(
          childName: '${child.firstName} ${child.lastName}'.trim(),
          assigned: childActivities.length,
          completed: childActivities
              .where(
                (activity) =>
                    activity.status.trim().toLowerCase() == 'completed' ||
                    (activity.id != null &&
                        childSubmissions.any(
                          (submission) => submission.activityId == activity.id,
                        )),
              )
              .length,
          awaitingReview: childSubmissions
              .where(
                (submission) =>
                    submission.reviewStatus.trim().toLowerCase() == 'pending',
              )
              .length,
          averageScore: averageScore,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _activityAnalytics = analytics;
        _isLoadingActivityAnalytics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activityAnalytics = children
            .map(
              (child) => _ChildActivityAnalytics(
                childName: '${child.firstName} ${child.lastName}'.trim(),
              ),
            )
            .toList();
        _isLoadingActivityAnalytics = false;
      });
    }
  }

  void _selectSection(int index) => setState(() => _selectedSection = index);

  Future<void> _openChildProfiles() async {
    // Keep Child Profiles inside the teacher workspace on web so it uses the
    // same persistent sidebar navigation as the other desktop sections.
    if (kIsWeb) {
      _selectSection(1);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChildListPage(
          teacherMode: true,
          onTeacherSectionSelected: _navigateFromChildProfiles,
        ),
      ),
    );
    if (mounted) _loadClassroomCount();
  }

  void _navigateFromChildProfiles(int index) {
    if (!mounted) return;
    if (index == 3) {
      setState(() => _isMoreOpen = true);
      return;
    }
    setState(() {
      _selectedSection = index;
      _isMoreOpen = false;
    });
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
        return const ChildListPage(
          teacherMode: true,
          showTeacherBottomNavigation: false,
        );
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
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const EccdAppBarTitle(
            title: 'ECCD GrowthTrack',
            subtitle: 'TEACHER WORKSPACE',
          ),
          backgroundColor: colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        bottomNavigationBar:
            keyboardVisible ||
                (kIsWeb && MediaQuery.sizeOf(context).width > 900)
            ? null
            : SafeArea(
                top: false,
                child: NavigationBar(
                  selectedIndex: _selectedSection <= 2 ? _selectedSection : 3,
                  onDestinationSelected: (index) {
                    if (index == 3) {
                      _showMoreSections();
                    } else if (index == 1 &&
                        !(kIsWeb && MediaQuery.sizeOf(context).width > 900)) {
                      setState(() => _isMoreOpen = false);
                      _openChildProfiles();
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
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dashboard = _TeacherWorkspaceHome(
                    childCount: _childCount,
                    isLoading: _isLoadingClassroom,
                    activityAnalytics: _activityAnalytics,
                    isLoadingActivityAnalytics: _isLoadingActivityAnalytics,
                    teacherName: _loggedInTeacher?.name ?? 'Teacher',
                    assignedChildren: _assignedChildren,
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
                              label: 'Child Profiles',
                              icon: Icons.person_add_outlined,
                              selected: _selectedSection == 1,
                              onTap: _openChildProfiles,
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
                          bottomItem: RoleWebNavItem(
                            label: 'Logout',
                            icon: Icons.logout_rounded,
                            isDestructive: true,
                            onTap: _logout,
                          ),
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
    required this.activityAnalytics,
    required this.isLoadingActivityAnalytics,
    required this.teacherName,
    required this.assignedChildren,
  });

  final int childCount;
  final bool isLoading;
  final List<_ChildActivityAnalytics> activityAnalytics;
  final bool isLoadingActivityAnalytics;
  final String teacherName;
  final List<ChildModel> assignedChildren;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final columns = constraints.maxWidth >= 1050 ? 3 : (isPhone ? 1 : 2);
        final horizontalPadding = isPhone ? 16.0 : 32.0;
        final contentWidth = constraints.maxWidth - (horizontalPadding * 2);
        final metricWidth = isPhone ? (contentWidth - 16) / 2 : 296.0;
        final childCardWidth = isPhone
            ? contentWidth
            : constraints.maxWidth >= 1050
            ? (contentWidth - 32) / 3
            : (contentWidth - 16) / 2;
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
                  height: isPhone ? 244 : 224,
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
                              'Welcome, $teacherName',
                              style: TextStyle(
                                color: Color(0xFF102A72),
                                fontSize: isPhone ? 28 : 34,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              'Logged in as teacher. Keep your active child profiles and parent links visible.',
                              maxLines: isPhone ? 4 : null,
                              overflow: isPhone ? TextOverflow.ellipsis : null,
                              style: const TextStyle(
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
                      width: metricWidth,
                      compact: isPhone,
                    ),
                    _TeacherMetric(
                      label: 'Attendance',
                      value: 'Ready',
                      icon: Icons.fact_check_rounded,
                      color: BrandColors.sky,
                      width: metricWidth,
                      compact: isPhone,
                    ),
                    _TeacherMetric(
                      label: 'Evaluations',
                      value: 'Review',
                      icon: Icons.auto_graph_rounded,
                      color: BrandColors.sunshine,
                      width: metricWidth,
                      compact: isPhone,
                    ),
                    _TeacherMetric(
                      label: 'Referrals',
                      value: '0',
                      icon: Icons.medical_services_rounded,
                      color: Color(0xFFE76F51),
                      width: metricWidth,
                      compact: isPhone,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'My active children',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Children assigned to your teacher account and their linked parent.',
                  style: TextStyle(color: Color(0xFF54769B)),
                ),
                const SizedBox(height: 14),
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (assignedChildren.isEmpty)
                  const _TeacherChildrenEmptyState()
                else
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: assignedChildren
                        .map(
                          (child) => _TeacherChildAssignmentCard(
                            child: child,
                            width: childCardWidth,
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 32),
                const Text(
                  'Child activity analytics',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                if (isLoadingActivityAnalytics)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (activityAnalytics.isEmpty)
                  const _ActivityAnalyticsEmptyState()
                else
                  GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: constraints.maxWidth >= 800
                        ? 1.65
                        : (isPhone ? 1.25 : 1.35),
                    children: activityAnalytics
                        .map(
                          (analytics) =>
                              _ChildActivityAnalyticsCard(analytics: analytics),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TeacherChildrenEmptyState extends StatelessWidget {
  const _TeacherChildrenEmptyState();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: BrandColors.sky.withValues(alpha: .18)),
    ),
    child: const Row(
      children: [
        Icon(Icons.groups_outlined, color: BrandColors.sky, size: 34),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            'No active child profiles are linked to your account yet. Use Register Child to create and link a child to a parent.',
            style: TextStyle(color: Color(0xFF54769B)),
          ),
        ),
      ],
    ),
  );
}

class _TeacherChildAssignmentCard extends StatelessWidget {
  const _TeacherChildAssignmentCard({required this.child, required this.width});

  final ChildModel child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final name = '${child.firstName} ${child.lastName}'.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final parentName = child.parentName.trim();
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrandColors.green.withValues(alpha: .24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: BrandColors.sky.withValues(alpha: .13),
                foregroundColor: BrandColors.navy,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Unnamed child' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Child ID: ${child.childId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF54769B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BrandColors.green.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: BrandColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.family_restroom_rounded,
                size: 18,
                color: BrandColors.navy,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  parentName.isEmpty
                      ? 'No parent linked yet'
                      : 'Parent: $parentName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF355875),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
    required this.compact,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: compact ? 104 : null,
    padding: EdgeInsets.all(compact ? 14 : 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: .18)),
    ),
    child: compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MetricIcon(icon: icon, color: color, compact: true),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        : Row(
            children: [
              _MetricIcon(icon: icon, color: color),
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

class _MetricIcon extends StatelessWidget {
  const _MetricIcon({
    required this.icon,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 38.0 : 42.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: compact ? 20 : 24),
    );
  }
}

class _ChildActivityAnalytics {
  const _ChildActivityAnalytics({
    required this.childName,
    this.assigned = 0,
    this.completed = 0,
    this.awaitingReview = 0,
    this.averageScore,
  });

  final String childName;
  final int assigned;
  final int completed;
  final int awaitingReview;
  final double? averageScore;

  double get completionRate => assigned == 0 ? 0 : completed / assigned;
}

class _ChildActivityAnalyticsCard extends StatelessWidget {
  const _ChildActivityAnalyticsCard({required this.analytics});

  final _ChildActivityAnalytics analytics;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: BrandColors.sky.withValues(alpha: .2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: BrandColors.sky.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.child_care_rounded,
                color: BrandColors.sky,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                analytics.childName.isEmpty ? 'Child' : analytics.childName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          analytics.assigned == 0
              ? 'No teacher activities assigned yet'
              : '${analytics.completed} of ${analytics.assigned} activities completed',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: analytics.completionRate,
            minHeight: 8,
            backgroundColor: BrandColors.sky.withValues(alpha: .12),
            valueColor: const AlwaysStoppedAnimation(BrandColors.green),
          ),
        ),
        const Spacer(),
        Row(
          children: [
            _AnalyticsValue(
              icon: Icons.rate_review_outlined,
              value: '${analytics.awaitingReview}',
              label: 'for review',
              color: BrandColors.sunshine,
            ),
            const SizedBox(width: 18),
            _AnalyticsValue(
              icon: Icons.auto_graph_rounded,
              value: analytics.averageScore == null
                  ? '—'
                  : '${(analytics.averageScore! * 100).round()}%',
              label: 'avg. score',
              color: BrandColors.navy,
            ),
          ],
        ),
      ],
    ),
  );
}

class _AnalyticsValue extends StatelessWidget {
  const _AnalyticsValue({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 5),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _ActivityAnalyticsEmptyState extends StatelessWidget {
  const _ActivityAnalyticsEmptyState();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: BrandColors.sky.withValues(alpha: .2)),
    ),
    child: const Row(
      children: [
        Icon(Icons.insights_rounded, color: BrandColors.sky, size: 38),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            'Assign activities to children to see their progress analytics here.',
          ),
        ),
      ],
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
