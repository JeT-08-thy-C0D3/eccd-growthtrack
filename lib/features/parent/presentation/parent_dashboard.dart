import 'package:flutter/material.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../reports/presentation/child_summary_report.dart';
import '../../home_activities/presentation/home_activities_page.dart'; // Reusing or creating parent version
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
        title: const Text('Parent Dashboard'),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              // Show mock notifications
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
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${_parentUser?.name}!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (_children.isEmpty)
                    const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('No children linked to your account. Please contact your child\'s teacher.'),
                        ),
                      ),
                    )
                  else
                    ..._children.map((child) => _ChildSummaryCard(child: child)),
                  const SizedBox(height: 24),
                  const Text('Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _ParentMenuCard(
                        title: 'Development\nSummary',
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
                        title: 'Development\nProgress',
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
                        title: 'Home\nActivities',
                        icon: Icons.home_work,
                        color: Colors.purple,
                        onTap: () {
                           if (_children.isNotEmpty) {
                            Navigator.pushNamed(context, '/home-activities');
                          }
                        },
                      ),
                      _ParentMenuCard(
                        title: 'Submit\nFeedback',
                        icon: Icons.message,
                        color: Colors.orange,
                        onTap: () => Navigator.pushNamed(context, '/feedback'),
                      ),
                      _ParentMenuCard(
                        title: 'Feedback\nHistory',
                        icon: Icons.history_edu,
                        color: Colors.deepOrange,
                        onTap: () => Navigator.pushNamed(context, '/feedback-history'),
                      ),
                      _ParentMenuCard(
                        title: 'Health &\nNutrition',
                        icon: Icons.favorite,
                        color: Colors.red,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Health logs coming soon')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(radius: 28, child: Icon(Icons.child_care, size: 32)),
        title: Text('${child.firstName} ${child.lastName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text('Age: ${child.age} yrs old | Gender: ${child.gender}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Show child details
        },
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
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
