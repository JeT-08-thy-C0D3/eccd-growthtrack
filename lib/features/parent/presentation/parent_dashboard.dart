import 'package:flutter/material.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../reports/presentation/child_summary_report.dart';
import '../../reports/domain/development_summary_model.dart';
import 'child_development_summary_view.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  UserModel? _parentUser;
  List<ChildModel> _children = [];
  DevelopmentSummaryModel? _latestSummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await AuthRepositoryImpl().getCurrentUser();
    if (user != null) {
      final children = await DatabaseHelper.instance.readChildrenByParent(user.id!);
      
      DevelopmentSummaryModel? summary;
      if (children.isNotEmpty) {
        final summaryMap = await DatabaseHelper.instance.getLatestApprovedSummary(children.first.childId);
        if (summaryMap != null) {
          summary = DevelopmentSummaryModel.fromMap(summaryMap);
        }
      }

      setState(() {
        _parentUser = user;
        _children = children;
        _latestSummary = summary;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Portal'),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
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

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, ${_parentUser?.name}!',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stay updated with your child\'s developmental journey.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
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
                        ..._children.map((child) => _ChildSummaryCard(child: child)),
                      const SizedBox(height: 40),
                      Text(
                        'Learning & Feedback',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isWide ? 3 : 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.3,
                        children: [
                          _ParentMenuCard(
                            title: 'Development Summary',
                            icon: Icons.auto_awesome,
                            color: Colors.purple,
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
                            color: Colors.blue,
                            onTap: () {
                              if (_children.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ChildSummaryReport(child: _children.first)),
                                );
                              }
                            },
                          ),
                          _ParentMenuCard(
                            title: 'Home Activities',
                            icon: Icons.home_work,
                            color: Colors.indigo,
                            onTap: () {
                               if (_children.isNotEmpty) {
                                Navigator.pushNamed(context, '/home-activities');
                              }
                            },
                          ),
                          _ParentMenuCard(
                            title: 'Submit Feedback',
                            icon: Icons.chat_bubble_outline,
                            color: Colors.orange,
                            onTap: () => Navigator.pushNamed(context, '/feedback'),
                          ),
                          _ParentMenuCard(
                            title: 'Feedback History',
                            icon: Icons.history_edu,
                            color: Colors.deepOrange,
                            onTap: () => Navigator.pushNamed(context, '/feedback-history'),
                          ),
                          _ParentMenuCard(
                            title: 'Health Logs',
                            icon: Icons.favorite_border,
                            color: Colors.red,
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
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            radius: 30, 
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: const Icon(Icons.child_care, size: 32, color: Colors.blue)
          ),
          title: Text('${child.firstName} ${child.lastName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(20)
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
