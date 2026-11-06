import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/data/auth_repository_impl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../reports/presentation/child_summary_report.dart';
import '../../reports/presentation/reports_page.dart';
import '../../reports/domain/development_summary_model.dart';
import '../../notification/data/notification_repository.dart';
import '../../notification/presentation/parent_notifications_page.dart';
import 'parent_home_activities_page.dart';
import '../../development_practice_activities/presentation/pages/practice_activities_page.dart';
import 'child_development_summary_view.dart';
import 'parent_clarification_page.dart';
import 'parent_feedback_history_page.dart';
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
  bool _isLoading = true;
  int _selectedSection = 0;

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
      case 5:
        return const ParentFeedbackHistoryPage();
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
            _moreSectionTile(
              'Updates',
              Icons.notifications_outlined,
              1,
            ),
            _moreSectionTile(
              'Send feedback',
              Icons.chat_bubble_outline,
              4,
            ),
            _moreSectionTile('Feedback history', Icons.history_edu_outlined, 5),
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

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
          _isLoading = false;
        });
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
    try {
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
        DevelopmentSummaryModel? summary;
        if (selectedChild != null) {
          final summaryMap = await _getLatestApprovedSummary(
            selectedChild.childId,
          );
          if (summaryMap != null) {
            summary = DevelopmentSummaryModel.fromMap(summaryMap);
          }
        }

        if (!mounted) return;
        setState(() {
          _parentUser = user;
          _children = children;
          _selectedChild = selectedChild;
          _latestSummary = summary;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final confirmed = await ConfirmationDialog.show(
                  context: context,
                  title: 'Confirm Logout',
                  message:
                      'Are you sure you want to log out from ECCD GrowthTrack?',
                  confirmLabel: 'Logout',
                  confirmColor: Colors.red,
                  icon: Icons.logout,
                );
                if (!confirmed) return;
                await AuthRepositoryImpl().logout();
                if (!context.mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(width: 8),
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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final isNarrow = constraints.maxWidth < 480;

                  final dashboard = _ParentWorkspaceHome(
                    parentName: _parentUser?.name ?? 'Parent',
                    child: _selectedChild,
                    onNavigate: (section) =>
                        setState(() => _selectedSection = section),
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
                              onTap: () => setState(() => _selectedSection = 0),
                            ),
                            RoleWebNavItem(
                              label: 'Notifications',
                              icon: Icons.notifications_outlined,
                              selected: _selectedSection == 1,
                              onTap: () => setState(() => _selectedSection = 1),
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
                              label: 'Feedback History',
                              icon: Icons.history_edu_outlined,
                              selected: _selectedSection == 5,
                              onTap: () => setState(() => _selectedSection = 5),
                            ),
                            RoleWebNavItem(
                              label: 'Clarifications',
                              icon: Icons.question_answer_outlined,
                              selected: _selectedSection == 6,
                              onTap: () => setState(() => _selectedSection = 6),
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
                    style: TextStyle(color: Color(0xFF526F9E), fontSize: 18),
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
    required this.onNavigate,
  });

  final String parentName;
  final ChildModel? child;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final columns = constraints.maxWidth >= 1000 ? 3 : 2;
        final horizontalPadding = isPhone ? 16.0 : 32.0;
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
            constraints: const BoxConstraints(maxWidth: 1280),
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
                                'Welcome back, $parentName',
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
                const Text(
                  'Family workspace',
                  style: TextStyle(
                    color: Color(0xFF10245E),
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: constraints.maxWidth >= 1000
                      ? 1.78
                      : (isPhone ? .76 : 1.3),
                  children: [
                    _ParentWorkspaceAction(
                      title: 'Notifications',
                      subtitle: 'See updates from your teacher',
                      icon: Icons.notifications_active_rounded,
                      color: BrandColors.sky,
                      compact: isPhone,
                      onTap: () => onNavigate(1),
                    ),
                    _ParentWorkspaceAction(
                      title: 'Home activities',
                      subtitle: 'Support learning at home',
                      icon: Icons.home_work_rounded,
                      color: BrandColors.green,
                      compact: isPhone,
                      onTap: () => onNavigate(2),
                    ),
                    _ParentWorkspaceAction(
                      title: 'Practice activities',
                      subtitle: 'Explore guided learning tasks',
                      icon: Icons.auto_awesome_rounded,
                      color: BrandColors.sunshine,
                      compact: isPhone,
                      onTap: () => onNavigate(3),
                    ),
                    _ParentWorkspaceAction(
                      title: 'Send feedback',
                      subtitle: 'Share an observation with the teacher',
                      icon: Icons.chat_bubble_rounded,
                      color: BrandColors.navy,
                      compact: isPhone,
                      onTap: () => onNavigate(4),
                    ),
                    _ParentWorkspaceAction(
                      title: 'Feedback history',
                      subtitle: 'Review your previous messages',
                      icon: Icons.history_rounded,
                      color: const Color(0xFFE76F51),
                      compact: isPhone,
                      onTap: () => onNavigate(5),
                    ),
                    _ParentWorkspaceAction(
                      title: 'Clarifications',
                      subtitle: 'Ask a question and get support',
                      icon: Icons.help_outline_rounded,
                      color: BrandColors.green,
                      compact: isPhone,
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
