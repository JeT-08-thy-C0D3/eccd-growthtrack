import 'package:flutter/material.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../reports/presentation/child_summary_report.dart';
import '../../reports/domain/development_summary_model.dart';
import '../../notification/data/notification_repository.dart';
import 'child_development_summary_view.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthRepositoryImpl().getCurrentUser();
      if (user != null) {
        final children = await DatabaseHelper.instance.readChildrenByParent(user.uid);

        final selectedChild = children.isEmpty
            ? null
            : children.firstWhere(
                (child) => child.childId == _selectedChild?.childId,
                orElse: () => children.first,
              );
        DevelopmentSummaryModel? summary;
        if (selectedChild != null) {
          final summaryMap = await DatabaseHelper.instance.getLatestApprovedSummary(selectedChild.childId);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
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
            stream: NotificationRepositoryImpl().getUnreadCountStream(_parentUser?.uid ?? ''),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.pushNamed(context, '/parent/notifications'),
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
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final isNarrow = constraints.maxWidth < 480;

                return SingleChildScrollView(
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
                              child: Text('No children linked to your account. Please contact the teacher.'),
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
                                  .map((child) => DropdownMenuItem(
                                        value: child,
                                        child: Text(
                                          '${child.firstName} ${child.lastName} (${child.childId})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (child) async {
                                if (child == null) return;
                                final summaryMap = await DatabaseHelper.instance.getLatestApprovedSummary(child.childId);
                                if (!mounted) return;
                                setState(() {
                                  _selectedChild = child;
                                  _latestSummary = summaryMap == null ? null : DevelopmentSummaryModel.fromMap(summaryMap);
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isWide ? 3 : (isNarrow ? 1 : 2),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: isWide ? 1.35 : (isNarrow ? 2.4 : 1.08),
                        children: [
                          _ParentMenuCard(
                            title: 'Development Summary',
                            icon: Icons.auto_awesome,
                            color: BrandColors.navy,
                            onTap: () {
                              if (_latestSummary != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ChildDevelopmentSummaryView(summary: _latestSummary!)),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No approved summary available yet.')),
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
                                  MaterialPageRoute(builder: (context) => ChildSummaryReport(child: _selectedChild!)),
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
                                Navigator.pushNamed(context, '/home-activities');
                              }
                            },
                          ),
                          _ParentMenuCard(
                            title: 'Practice Activities',
                            icon: Icons.self_improvement,
                            color: BrandColors.green,
                            onTap: () => Navigator.pushNamed(context, '/parent/practice-activities'),
                          ),
                          _ParentMenuCard(
                            title: 'Submit Feedback',
                            icon: Icons.chat_bubble_outline,
                            color: BrandColors.sunshine,
                            onTap: () => Navigator.pushNamed(context, '/feedback'),
                          ),
                          _ParentMenuCard(
                            title: 'Feedback History',
                            icon: Icons.history_edu,
                            color: const Color(0xFFE76F51),
                            onTap: () => Navigator.pushNamed(context, '/feedback-history'),
                          ),
                          _ParentMenuCard(
                            title: 'Clarification Requests',
                            icon: Icons.question_answer,
                            color: BrandColors.green,
                            onTap: () => Navigator.pushNamed(context, '/clarifications'),
                          ),
                          _ParentMenuCard(
                            title: 'Health Logs',
                            icon: Icons.favorite_border,
                            color: const Color(0xFFE76F51),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Health logs feature is coming soon.')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
            ),
    );
  }
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: CircleAvatar(
            radius: 30,
            backgroundColor: BrandColors.sky.withValues(alpha: 0.12),
            child: const Icon(Icons.child_care, size: 32, color: BrandColors.sky)
          ),
          title: Text('${child.firstName} ${child.lastName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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

  const _ParentMenuCard({required this.title, required this.icon, required this.color, required this.onTap});

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
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  Icon(Icons.arrow_outward_rounded, size: 20, color: colors.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, color: colors.onSurface, fontSize: 14, height: 1.15),
              ),
              const SizedBox(height: 6),
              Text('View details', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
