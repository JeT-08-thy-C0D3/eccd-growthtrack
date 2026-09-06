import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';

class ParentHomeActivitiesPage extends StatefulWidget {
  final ChildModel child;
  const ParentHomeActivitiesPage({super.key, required this.child});

  @override
  State<ParentHomeActivitiesPage> createState() => _ParentHomeActivitiesPageState();
}

class _ParentHomeActivitiesPageState extends State<ParentHomeActivitiesPage> {
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getHomeActivitiesByChild(widget.child.id!);
    setState(() {
      _activities = data;
      _isLoading = false;
    });
  }

  Future<void> _markAsDone(int activityId) async {
    await DatabaseHelper.instance.updateHomeActivityStatus(activityId, 'Completed');
    _loadActivities();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity marked as completed! Good job!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Activities for ${widget.child.firstName} ${widget.child.lastName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No home activities assigned yet.'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    final isCompleted = activity['status'] == 'Completed';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  activity['title'],
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    activity['status'],
                                    style: TextStyle(
                                      color: isCompleted ? Colors.green : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(activity['description']),
                            const SizedBox(height: 16),
                            Text(
                              'Assigned on: ${activity['date_assigned']}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (!isCompleted) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _markAsDone(activity['id']),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Mark as Done'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
