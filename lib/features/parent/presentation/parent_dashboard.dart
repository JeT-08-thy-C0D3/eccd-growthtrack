import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/data/auth_repository_impl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../reports/presentation/child_summary_report.dart';
import '../../reports/presentation/reports_page.dart';
import '../../reports/domain/development_summary_model.dart';
import '../../notification/data/notification_repository.dart';
import '../../notification/presentation/parent_notifications_page.dart';
import '../../home_activities/data/activity_repository.dart';
import '../../home_activities/domain/activity_model.dart';
import '../../home_activities/domain/activity_submission_model.dart';
import 'parent_home_activities_page.dart';
import '../../development_practice_activities/presentation/pages/practice_activities_page.dart';
import 'child_development_summary_view.dart';
import 'parent_clarification_page.dart';
import 'parent_feedback_page.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/role_web_sidebar.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  UserModel? _parentUser;
  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
  DevelopmentSummaryModel? _latestSummary;
  bool _isLoadingChildAnalytics = false;
  int _selectedSection = 0;
  final ActivityRepository _activityRepository = ActivityRepositoryImpl();
  _ParentChildAnalytics? _childAnalytics;

  Widget _buildSelectedSection() {
    switch (_selectedSection) {
      case 1:
        return const ParentNotificationsPage();
      case 2:
        return _selectedChild == null
            ? const _ParentActivitiesUnavailable()
            : ParentHomeActivitiesPage(child: _selectedChild!);
      case 3:
        return const PracticeActivitiesPage();
      case 4:
        return const ParentFeedbackPage();
      case 6:
        return const ParentClarificationPage();
      default:
        return ReportsPage(
          embedded: true,
          initialFilterChild: _selectedChild,
          showReferrals: false,
        );
    }
  }

  void _showNotificationsModal() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenSize = MediaQuery.sizeOf(dialogContext);
        final isCompact = screenSize.width < 760;
        return Dialog(
          insetPadding: EdgeInsets.all(isCompact ? 16 : 32),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SizedBox(
            width: isCompact ? screenSize.width - 32 : 1120,
            height: screenSize.height * .86,
            child: Stack(
              children: [
                const ParentNotificationsPage(),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white.withValues(alpha: .9),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close notifications',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoreSections() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _moreSectionTile('Updates', Icons.notifications_outlined, 1),
            _moreSectionTile('Send feedback', Icons.chat_bubble_outline, 4),
            _moreSectionTile(
              'Clarifications',
              Icons.question_answer_outlined,
              6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _moreSectionTile(String label, IconData icon, int index) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    selected: _selectedSection == index,
    onTap: () {
      Navigator.pop(context);
      setState(() => _selectedSection = index);
    },
  );

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Mobile renders its saved SQLite records first. This avoids holding the
    // whole dashboard on a network request every time it is opened.
    if (!kIsWeb) {
      final cachedUser = await _readCachedParent();
      if (cachedUser != null) {
        final cachedChildren = await DatabaseHelper.instance
            .readChildrenByParent(cachedUser.uid, allowCloudFallback: false);
        if (!mounted) return;
        setState(() {
          _parentUser = cachedUser;
          _children = cachedChildren;
          _selectedChild = cachedChildren.isEmpty ? null : cachedChildren.first;
        });
        unawaited(_loadChildAnalytics(_selectedChild));
        // Refresh after the cached view is visible; any newly saved cloud data
        // is cached by DatabaseHelper for the next dashboard open.
        unawaited(_refreshFromCloud());
        return;
      }
    }

    await _refreshFromCloud();
  }

  Future<UserModel?> _readCachedParent() async {
    final firebaseUid = AuthRepositoryImpl().firebaseUserId;
    if (firebaseUid == null) return null;
    final users = await DatabaseHelper.instance.readAllUsers();
    for (final user in users) {
      if (user.uid == firebaseUid) return user;
    }
    return null;
  }

  Future<void> _refreshFromCloud() async {
    final user = await AuthRepositoryImpl().getCurrentUser();
    if (user != null) {
      final children = kIsWeb
          ? await _readChildrenFromFirestore(user.uid, user.name)
          : await DatabaseHelper.instance.readChildrenByParent(user.uid);

      final selectedChild = children.isEmpty
          ? null
          : children.firstWhere(
              (child) => child.childId == _selectedChild?.childId,
              orElse: () => children.first,
            );
      if (!mounted) return;
      setState(() {
        _parentUser = user;
        _children = children;
        _selectedChild = selectedChild;
        _latestSummary = null;
      });
      // Keep the dashboard usable while the slower summary and activity
      // queries finish in the background.
      unawaited(_loadLatestSummary(selectedChild));
      unawaited(_loadChildAnalytics(selectedChild));
    }
  }

  Future<List<ChildModel>> _readChildrenFromFirestore(
    String parentUid,
    String parentName,
  ) async {
    var snapshot = await FirebaseFirestore.instance
        .collection('children')
        .where('parent_uid', isEqualTo: parentUid)
        .get();
    if (snapshot.docs.isEmpty && parentName.trim().isNotEmpty) {
      snapshot = await FirebaseFirestore.instance
          .collection('children')
          .where('parent_name', isEqualTo: parentName)
          .get();
    }
    return snapshot.docs.map((doc) => ChildModel.fromMap(doc.data())).toList();
  }

  Future<Map<String, dynamic>?> _getLatestApprovedSummary(
    String childId,
  ) async {
    if (!kIsWeb) {
      return DatabaseHelper.instance.getLatestApprovedSummary(childId);
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('development_summaries')
        .where('child_id', isEqualTo: childId)
        .where('approval_status', isEqualTo: 'Approved')
        .limit(1)
        .get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first.data();
  }

  Future<void> _loadLatestSummary(ChildModel? child) async {
    if (child == null) return;
    try {
      final summaryMap = await _getLatestApprovedSummary(child.childId);
      if (!mounted) return;
      setState(
        () => _latestSummary = summaryMap == null
            ? null
            : DevelopmentSummaryModel.fromMap(summaryMap),
      );
    } catch (_) {
      // A missing or unavailable report should never delay the dashboard.
    }
  }

  Future<void> _loadChildAnalytics(ChildModel? child) async {
    if (child == null) {
      if (mounted) {
        setState(() {
          _childAnalytics = null;
          _isLoadingChildAnalytics = false;
        });
      }
      return;
    }

    try {
      List<Map<String, dynamic>> attendance;
      List<ActivityModel> activities;
      List<ActivitySubmissionModel> submissions;

      if (kIsWeb) {
        final parentUid =
            _parentUser?.uid ?? AuthRepositoryImpl().firebaseUserId;
        if (parentUid == null || parentUid.isEmpty) {
          throw StateError('The parent session is not available.');
        }
        // Fetch each dashboard source independently. A missing permission or
        // a temporary attendance error must not erase a valid completed home
        // activity and turn every card into 0.
        attendance = const [];
        activities = const [];
        submissions = const [];
        try {
          final activitySnapshot = await FirebaseFirestore.instance
              .collection('activities')
              .where('child_id', isEqualTo: child.childId)
              .where('parent_uid', isEqualTo: parentUid)
              .get(const GetOptions(source: Source.server));
          activities = activitySnapshot.docs
              .map(
                (doc) => ActivityModel.fromMap({
                  ...doc.data(),
                  'id': doc.data()['id'] ?? int.tryParse(doc.id),
                }),
              )
              .toList();
        } catch (_) {}
        try {
          final submissionSnapshot = await FirebaseFirestore.instance
              .collection('activity_submissions')
              .where('child_id', isEqualTo: child.childId)
              .where('parent_uid', isEqualTo: parentUid)
              .get(const GetOptions(source: Source.server));
          submissions = submissionSnapshot.docs
              .map(
                (doc) => ActivitySubmissionModel.fromMap({
                  ...doc.data(),
                  'id': doc.data()['id'] ?? int.tryParse(doc.id),
                }),
              )
              .toList();
        } catch (_) {}
        try {
          final attendanceSnapshot = await FirebaseFirestore.instance
              .collection('attendance_events')
              .where('child_id', isEqualTo: child.childId)
              .get(const GetOptions(source: Source.server));
          attendance = attendanceSnapshot.docs
              .map((doc) => <String, dynamic>{...doc.data()})
              .toList();
        } catch (_) {}
      } else {
        attendance = await DatabaseHelper.instance.getChildAttendanceHistory(
          child.childId,
        );
        activities = await _activityRepository.getActivitiesForChild(
          child.childId,
        );
        submissions = (await _activityRepository.getAllSubmissions())
            .where((item) => item['child_id'] == child.childId)
            .map(ActivitySubmissionModel.fromMap)
            .toList();
      }

      attendance.sort(
        (a, b) => '${b['attendance_date'] ?? ''} ${b['attendance_time'] ?? ''}'
            .compareTo(
              '${a['attendance_date'] ?? ''} ${a['attendance_time'] ?? ''}',
            ),
      );
      activities.sort((a, b) => b.createdDate.compareTo(a.createdDate));
      final activityById = {
        for (final activity in activities)
          if (activity.id != null) activity.id!: activity,
      };
      final submittedActivityIds = submissions
          .map((submission) => submission.activityId)
          .toSet();
      final completedActivities = activities
          .where(
            (activity) =>
                activity.status.trim().toLowerCase() == 'completed' ||
                (activity.id != null &&
                    submittedActivityIds.contains(activity.id)),
          )
          .length;
      final scoredSubmissions = submissions
          .where(
            (submission) =>
                submission.score != null &&
                (activityById[submission.activityId]?.maxScore ?? 0) > 0,
          )
          .toList();
      final averageScore = scoredSubmissions.isEmpty
          ? null
          : scoredSubmissions
                    .map(
                      (submission) =>
                          submission.score! /
                          activityById[submission.activityId]!.maxScore,
                    )
                    .reduce((total, value) => total + value) /
                scoredSubmissions.length;
      final present = attendance
          .where(
            (item) => item['status']?.toString().toLowerCase() == 'present',
          )
          .length;

      if (!mounted) return;
      setState(() {
        _childAnalytics = _ParentChildAnalytics(
          attendanceStatus: attendance.isEmpty
              ? 'No attendance record'
              : attendance.first['status']?.toString() ?? 'Recorded',
          attendanceDate: attendance.isEmpty
              ? null
              : attendance.first['attendance_date']?.toString(),
          attendanceRate: attendance.isEmpty
              ? null
              : present / attendance.length,
          assignedActivities: activities.isEmpty
              ? submittedActivityIds.length
              : activities.length,
          completedActivities: completedActivities,
          averageScore: averageScore,
          recentActivities: activities.take(3).toList(),
        );
        _isLoadingChildAnalytics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _childAnalytics = const _ParentChildAnalytics();
        _isLoadingChildAnalytics = false;
      });
    }
  }

  void _openDashboard() {
    setState(() => _selectedSection = 0);
    // Home Activities updates its activity document while the parent is in
    // that section. Refresh this metric on return instead of showing a stale
    // completed count from the initial dashboard load.
    unawaited(_loadChildAnalytics(_selectedChild));
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
            subtitle: 'PARENT PORTAL',
          ),
          centerTitle: false,
          backgroundColor: colorScheme.surface,
          elevation: 0,
          actions: [
            StreamBuilder<int>(
              stream: NotificationRepositoryImpl().getUnreadCountStream(
                _parentUser?.uid ?? '',
              ),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Notifications',
                      onPressed: _showNotificationsModal,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (!(kIsWeb && MediaQuery.sizeOf(context).width > 900)) ...[
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: _logout,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        bottomNavigationBar: kIsWeb && MediaQuery.sizeOf(context).width > 900
            ? null
            : NavigationBar(
                selectedIndex: switch (_selectedSection) {
                  0 => 0,
                  3 => 1,
                  2 => 2,
                  _ => 3,
                },
                onDestinationSelected: (index) {
                  if (index == 3) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _showMoreSections();
                    });
                  } else if (index == 0) {
                    _openDashboard();
                  } else {
                    setState(
                      () => _selectedSection = switch (index) {
                        0 => 0,
                        1 => 3,
                        _ => 2,
                      },
                    );
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.self_improvement_outlined),
                    selectedIcon: Icon(Icons.self_improvement),
                    label: 'Practice',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.home_work_outlined),
                    selectedIcon: Icon(Icons.home_work),
                    label: 'Activities',
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
            final firebaseDisplayName =
                FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
            final dashboard = _ParentWorkspaceHome(
              parentName: _parentUser?.name.trim().isNotEmpty == true
                  ? _parentUser!.name
                  : firebaseDisplayName,
              child: _selectedChild,
              analytics: _childAnalytics,
              isLoadingAnalytics: _isLoadingChildAnalytics,
              developmentSummary: _latestSummary,
            );
            /*final dashboard = SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EccdSectionIntro(
                          title: 'Hi, ${_parentUser?.name ?? 'Parent'}!',
                          subtitle: 'Stay updated with your child\'s developmental journey and celebrate every milestone.',
                          icon: Icons.family_restroom_rounded,
                        ),
                        const SizedBox(height: 32),
                        if (_children.isEmpty)
                          const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text(
                                  'No children linked to your account. Please contact the teacher.',
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<ChildModel>(
                                initialValue: _selectedChild,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'View child',
                                  prefixIcon: Icon(Icons.child_care),
                                ),
                                items: _children
                                    .map(
                                      (child) => DropdownMenuItem(
                                        value: child,
                                        child: Text(
                                          '${child.firstName} ${child.lastName} (${child.childId})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (child) async {
                                  if (child == null) return;
                                  final summaryMap =
                                      await _getLatestApprovedSummary(
                                        child.childId,
                                      );
                                  if (!mounted) return;
                                  setState(() {
                                    _selectedChild = child;
                                    _latestSummary = summaryMap == null
                                        ? null
                                        : DevelopmentSummaryModel.fromMap(
                                            summaryMap,
                                          );
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              _ChildSummaryCard(child: _selectedChild!),
                            ],
                          ),
                        const SizedBox(height: 40),
                        Text(
                          'Learning & Feedback',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isWide ? 3 : (isNarrow ? 1 : 2),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: isWide
                              ? 1.35
                              : (isNarrow ? 2.4 : 1.08),
                          children: [
                            _ParentMenuCard(
                              title: 'Development Summary',
                              icon: Icons.auto_awesome,
                              color: BrandColors.navy,
                              onTap: () {
                                if (_latestSummary != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ChildDevelopmentSummaryView(
                                            summary: _latestSummary!,
                                          ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No approved summary available yet.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            _ParentMenuCard(
                              title: 'Development Progress',
                              icon: Icons.auto_graph,
                              color: BrandColors.sky,
                              onTap: () {
                                if (_selectedChild != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChildSummaryReport(
                                        child: _selectedChild!,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            _ParentMenuCard(
                              title: 'Home Activities',
                              icon: Icons.home_work,
                              color: BrandColors.navy,
                              onTap: () {
                                if (_selectedChild != null) {
                                  Navigator.pushNamed(
                                    context,
                                    '/home-activities',
                                  );
                                }
                              },
                            ),
                            _ParentMenuCard(
                              title: 'Practice Activities',
                              icon: Icons.self_improvement,
                              color: BrandColors.green,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/parent/practice-activities',
                              ),
                            ),
                            _ParentMenuCard(
                              title: 'Submit Feedback',
                              icon: Icons.chat_bubble_outline,
                              color: BrandColors.sunshine,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/feedback'),
                            ),
                            _ParentMenuCard(
                              title: 'Feedback History',
                              icon: Icons.history_edu,
                              color: const Color(0xFFE76F51),
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/feedback-history',
                              ),
                            ),
                            _ParentMenuCard(
                              title: 'Clarification Requests',
                              icon: Icons.question_answer,
                              color: BrandColors.green,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/clarifications',
                              ),
                            ),
                            _ParentMenuCard(
                              title: 'Health Logs',
                              icon: Icons.favorite_border,
                              color: const Color(0xFFE76F51),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Health logs feature is coming soon.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );*/
            if (kIsWeb && constraints.maxWidth > 900) {
              return Row(
                children: [
                  RoleWebSidebar(
                    title: 'Parent Portal',
                    subtitle: 'FAMILY WORKSPACE',
                    showIdentityLogo: false,
                    items: [
                      RoleWebNavItem(
                        label: 'Dashboard',
                        icon: Icons.dashboard_outlined,
                        selected: _selectedSection == 0,
                        onTap: _openDashboard,
                      ),
                      RoleWebNavItem(
                        label: 'Home Activities',
                        icon: Icons.home_work_outlined,
                        selected: _selectedSection == 2,
                        onTap: () => setState(() => _selectedSection = 2),
                      ),
                      RoleWebNavItem(
                        label: 'Practice Activities',
                        icon: Icons.self_improvement_outlined,
                        selected: _selectedSection == 3,
                        onTap: () => setState(() => _selectedSection = 3),
                      ),
                      RoleWebNavItem(
                        label: 'Submit Feedback',
                        icon: Icons.chat_bubble_outline,
                        selected: _selectedSection == 4,
                        onTap: () => setState(() => _selectedSection = 4),
                      ),
                      RoleWebNavItem(
                        label: 'Clarifications',
                        icon: Icons.question_answer_outlined,
                        selected: _selectedSection == 6,
                        onTap: () => setState(() => _selectedSection = 6),
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
            return _selectedSection == 0 ? dashboard : _buildSelectedSection();
          },
        ),
      ),
    );
  }
}

class _ParentActivitiesUnavailable extends StatelessWidget {
  const _ParentActivitiesUnavailable();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF8FCFF),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            children: [
              const _ParentHomeActivitiesHero(),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 580),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: BrandColors.sky.withValues(alpha: .08),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.child_friendly_rounded,
                        size: 126,
                        color: BrandColors.sky,
                      ),
                      SizedBox(height: 31),
                      Text(
                        'No child profile is linked to this account yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF07135B),
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Once a child profile is linked, you’ll be able to access\nhome activities and personalised learning resources here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF7183AA),
                          fontSize: 17,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ParentHomeActivitiesHero extends StatelessWidget {
  const _ParentHomeActivitiesHero();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      return Container(
        width: double.infinity,
        height: compact ? 250 : 205,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 22 : 28,
          vertical: compact ? 20 : 24,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFEAF8FF), Color(0xFFD8F0FF)],
          ),
        ),
        child: Stack(
          children: [
            if (!compact)
              Positioned(
                right: 22,
                bottom: -48,
                child: Icon(
                  Icons.family_restroom_rounded,
                  size: 230,
                  color: const Color(0xFFFF8494).withValues(alpha: .76),
                ),
              ),
            if (!compact)
              Positioned(
                right: 195,
                bottom: -15,
                child: Icon(
                  Icons.spa_rounded,
                  size: 116,
                  color: BrandColors.green.withValues(alpha: .55),
                ),
              ),
            if (!compact)
              Positioned(
                right: 28,
                top: 24,
                child: const Icon(
                  Icons.home_rounded,
                  size: 46,
                  color: BrandColors.sunshine,
                ),
              ),
            compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: const Color(0xFF168FEA),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Icon(
                          Icons.home_rounded,
                          size: 35,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Home Activities',
                        style: TextStyle(
                          color: Color(0xFF07135B),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Explore and complete activities for your child’s learning at home.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF526F9E),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: const Color(0xFF168FEA),
                          borderRadius: BorderRadius.circular(23),
                        ),
                        child: const Icon(
                          Icons.home_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 25),
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Home Activities',
                              style: TextStyle(
                                color: Color(0xFF07135B),
                                fontSize: 39,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Explore and complete activities for your child’s learning at home.',
                              style: TextStyle(
                                color: Color(0xFF526F9E),
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      );
    },
  );
}

class _ParentWorkspaceHome extends StatelessWidget {
  const _ParentWorkspaceHome({
    required this.parentName,
    required this.child,
    required this.analytics,
    required this.isLoadingAnalytics,
    required this.developmentSummary,
  });

  final String parentName;
  final ChildModel? child;
  final _ParentChildAnalytics? analytics;
  final bool isLoadingAnalytics;
  final DevelopmentSummaryModel? developmentSummary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final horizontalPadding = isPhone ? 16.0 : 32.0;
        final welcomeText = parentName.trim().isEmpty
            ? 'Welcome!'
            : 'Welcome, $parentName!';
        final childName = child == null
            ? 'your child'
            : '${child!.firstName} ${child!.lastName}';
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: isPhone ? 230 : 215,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE5FFF0), Color(0xFFDDF7FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      if (isPhone)
                        Positioned(
                          right: -18,
                          bottom: -12,
                          child: Icon(
                            Icons.family_restroom_rounded,
                            color: const Color(0xFF2A9BEC)
                                .withValues(alpha: .62),
                            size: 126,
                          ),
                        ),
                      if (!isPhone && constraints.maxWidth >= 780) ...[
                        Positioned(
                          right: 60,
                          bottom: -46,
                          child: Icon(
                            Icons.family_restroom_rounded,
                            color: const Color(0xFF2A9BEC)
                                .withValues(alpha: .78),
                            size: 255,
                          ),
                        ),
                        Positioned(
                          right: 15,
                          bottom: -23,
                          child: Icon(
                            Icons.family_restroom_rounded,
                            color: const Color(0xFFFF7B89)
                                .withValues(alpha: .82),
                            size: 210,
                          ),
                        ),
                        Positioned(
                          right: 265,
                          bottom: -18,
                          child: Icon(
                            Icons.spa_rounded,
                            color: BrandColors.green.withValues(alpha: .53),
                            size: 145,
                          ),
                        ),
                        Positioned(
                          right: 27,
                          top: 15,
                          child: Icon(
                            Icons.wb_sunny_rounded,
                            color: BrandColors.sunshine.withValues(alpha: .85),
                            size: 49,
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: isPhone
                              ? double.infinity
                              : constraints.maxWidth < 780
                              ? double.infinity
                              : 620,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                welcomeText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF102A72),
                                  fontSize: isPhone ? 28 : 39,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Stay connected to $childName\'s learning journey.',
                                maxLines: isPhone ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF517594),
                                  fontSize: isPhone ? 15 : 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _ConnectedChildCard(child: child),
                const SizedBox(height: 22),
                const Text(
                  'Child overview',
                  style: TextStyle(
                    color: Color(0xFF10245E),
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                if (isLoadingAnalytics)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final analyticsCardWidth =
                          cardConstraints.maxWidth >= 1450
                          ? (cardConstraints.maxWidth - 64) / 5
                          : cardConstraints.maxWidth >= 1000
                          ? (cardConstraints.maxWidth - 32) / 3
                          : (isPhone
                                ? cardConstraints.maxWidth
                                : (cardConstraints.maxWidth - 16) / 2);
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _ChildAnalyticsMetric(
                            label: 'Latest attendance',
                            value: analytics?.attendanceStatus ?? 'No record',
                            detail: analytics?.attendanceDate == null
                                ? 'No attendance recorded yet'
                                : 'Latest record: ${analytics!.attendanceDate}',
                            icon: Icons.contactless_rounded,
                            color: _attendanceColor(
                              analytics?.attendanceStatus,
                            ),
                            width: analyticsCardWidth,
                          ),
                          _ChildAnalyticsMetric(
                            label: 'Attendance rate',
                            value: analytics?.attendanceRate == null
                                ? '—'
                                : '${(analytics!.attendanceRate! * 100).round()}%',
                            detail: 'Based on recorded attendance',
                            icon: Icons.calendar_month_rounded,
                            color: BrandColors.green,
                            width: analyticsCardWidth,
                          ),
                          _ChildAnalyticsMetric(
                            label: 'Activities completed',
                            value: '${analytics?.completedActivities ?? 0}',
                            detail:
                                'of ${analytics?.assignedActivities ?? 0} assigned activities',
                            icon: Icons.task_alt_rounded,
                            color: BrandColors.green,
                            width: analyticsCardWidth,
                          ),
                          _ChildAnalyticsMetric(
                            label: 'Activities to complete',
                            value: '${analytics?.remainingActivities ?? 0}',
                            detail: 'Activities still waiting to be completed',
                            icon: Icons.pending_actions_rounded,
                            color: BrandColors.sky,
                            width: analyticsCardWidth,
                          ),
                          _ChildAnalyticsMetric(
                            label: 'Learning performance',
                            value: analytics?.averageScore == null
                                ? (developmentSummary == null
                                      ? 'Pending'
                                      : 'Ready')
                                : '${(analytics!.averageScore! * 100).round()}%',
                            detail: analytics?.averageScore == null
                                ? (developmentSummary == null
                                      ? 'Awaiting teacher review'
                                      : 'Development summary is available')
                                : '${analytics!.completedActivities} of ${analytics!.assignedActivities} activities completed',
                            icon: Icons.auto_graph_rounded,
                            color: BrandColors.sunshine,
                            width: analyticsCardWidth,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Recent teacher activities',
                    style: TextStyle(
                      color: Color(0xFF10245E),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RecentTeacherActivities(
                    activities: analytics?.recentActivities ?? const [],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _attendanceColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'present':
        return BrandColors.green;
      case 'late':
        return BrandColors.sunshine;
      case 'absent':
        return const Color(0xFFE76F51);
      default:
        return BrandColors.sky;
    }
  }
}

class _ParentChildAnalytics {
  const _ParentChildAnalytics({
    this.attendanceStatus = 'No attendance record',
    this.attendanceDate,
    this.attendanceRate,
    this.assignedActivities = 0,
    this.completedActivities = 0,
    this.averageScore,
    this.recentActivities = const [],
  });

  final String attendanceStatus;
  final String? attendanceDate;
  final double? attendanceRate;
  final int assignedActivities;
  final int completedActivities;
  final double? averageScore;
  final List<ActivityModel> recentActivities;

  int get remainingActivities => completedActivities >= assignedActivities
      ? 0
      : assignedActivities - completedActivities;
}

class _ConnectedChildCard extends StatelessWidget {
  const _ConnectedChildCard({required this.child});

  final ChildModel? child;

  @override
  Widget build(BuildContext context) {
    if (child == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BrandColors.sky.withValues(alpha: .22)),
        ),
        child: const Row(
          children: [
            Icon(Icons.person_search_rounded, color: BrandColors.sky, size: 34),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No child profile is connected to this parent account yet.',
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.sky.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: BrandColors.sky.withValues(alpha: .12),
            child: const Icon(
              Icons.child_care_rounded,
              color: BrandColors.sky,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connected child',
                  style: TextStyle(
                    color: Color(0xFF58709D),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${child!.firstName} ${child!.lastName}',
                  style: const TextStyle(
                    color: Color(0xFF10245E),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Age ${child!.age} • Child ID: ${child!.childId}',
                  style: const TextStyle(
                    color: Color(0xFF58709D),
                    fontSize: 13,
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

class _ChildAnalyticsMetric extends StatelessWidget {
  const _ChildAnalyticsMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.width,
  });

  final String label;
  final String value;
  final String detail;
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
      border: Border.all(color: color.withValues(alpha: .22)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 16),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}

class _RecentTeacherActivities extends StatelessWidget {
  const _RecentTeacherActivities({required this.activities});

  final List<ActivityModel> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BrandColors.sky.withValues(alpha: .2)),
        ),
        child: const Text('No teacher activities have been uploaded yet.'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrandColors.sky.withValues(alpha: .2)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: BrandColors.sky.withValues(alpha: .14)),
        itemBuilder: (context, index) {
          final activity = activities[index];
          final completed = activity.status == 'Completed';
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: (completed ? BrandColors.green : BrandColors.sky)
                  .withValues(alpha: .12),
              child: Icon(
                completed
                    ? Icons.check_circle_rounded
                    : Icons.assignment_outlined,
                color: completed ? BrandColors.green : BrandColors.sky,
              ),
            ),
            title: Text(
              activity.activityTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${activity.developmentalDomain} • Uploaded: ${activity.createdDate}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              activity.status,
              style: TextStyle(
                color: completed ? BrandColors.green : BrandColors.sky,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ParentWorkspaceAction extends StatelessWidget {
  const _ParentWorkspaceAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.compact = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: .075),
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 14 : 28,
          compact ? 14 : 23,
          compact ? 14 : 22,
          compact ? 14 : 20,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: .9),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: compact ? -8 : -14,
              top: compact ? 4 : 6,
              child: Icon(
                icon,
                size: compact ? 74 : 118,
                color: color.withValues(alpha: .11),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 48 : 72,
                  height: compact ? 48 : 72,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(compact ? 15 : 21),
                  ),
                  child: Icon(icon, color: color, size: compact ? 26 : 38),
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    color: Color(0xFF10245E),
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 16 : 22,
                  ),
                ),
                SizedBox(height: compact ? 4 : 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          color: Color(0xFF58709D),
                          fontSize: compact ? 11 : 15,
                          height: 1.3,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 4 : 8),
                    Container(
                      width: compact ? 34 : 50,
                      height: compact ? 34 : 50,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF10245E),
                        size: compact ? 20 : 29,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChildSummaryCard extends StatelessWidget {
  final ChildModel child;
  const _ChildSummaryCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: BrandColors.sky.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 30,
            backgroundColor: BrandColors.sky.withValues(alpha: 0.12),
            child: const Icon(
              Icons.child_care,
              size: 32,
              color: BrandColors.sky,
            ),
          ),
          title: Text(
            '${child.firstName} ${child.lastName}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          subtitle: Text('Age: ${child.age} yrs • ID: ${child.childId}'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () {},
        ),
      ),
    );
  }
}

class _ParentMenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ParentMenuCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                  fontSize: 14,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'View details',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
