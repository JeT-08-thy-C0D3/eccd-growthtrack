import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/activity_repository.dart';
import '../domain/activity_model.dart';
import 'activity_submission_page.dart';
import 'activity_review_page.dart';

class ActivityManagementPage extends StatefulWidget {
  const ActivityManagementPage({super.key});

  @override
  State<ActivityManagementPage> createState() => _ActivityManagementPageState();
}

class _ActivityManagementPageState extends State<ActivityManagementPage> {
  final ActivityRepository _repository = ActivityRepositoryImpl();
  List<ActivityModel> _activities = [];
  List<ChildModel> _children = [];
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _currentUser = await AuthRepositoryImpl().getCurrentUser();
    
    if (_currentUser?.role == UserRole.teacher) {
      _activities = await _repository.getAllActivities();
      _children = await DatabaseHelper.instance.getAllChildren();
    } else if (_currentUser?.role == UserRole.parent) {
      final children = await DatabaseHelper.instance.readChildrenByParent(_currentUser!.id!);
      if (children.isNotEmpty) {
        _activities = await _repository.getActivitiesForChild(children.first.childId);
      }
    }

    setState(() => _isLoading = false);
  }

  void _showCreateActivityDialog() {
    final titleController = TextEditingController();
    final instructionsController = TextEditingController();
    ChildModel? selectedChild = _children.isNotEmpty ? _children.first : null;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Home Activity'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ChildModel>(
                  initialValue: selectedChild,
                  decoration: const InputDecoration(labelText: 'Assign to Child'),
                  items: _children.map((c) => DropdownMenuItem(value: c, child: Text("${c.firstName} ${c.lastName}"))).toList(),
                  onChanged: (val) => setDialogState(() => selectedChild = val),
                ),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Activity Title')),
                TextField(controller: instructionsController, decoration: const InputDecoration(labelText: 'Instructions'), maxLines: 3),
                ListTile(
                  title: Text("Due Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}"),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedChild == null || titleController.text.isEmpty) return;
                final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
                final activity = ActivityModel(
                  childId: selectedChild!.childId,
                  activityTitle: titleController.text,
                  instructions: instructionsController.text,
                  dueDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                  assignedBy: _currentUser?.name ?? 'Teacher',
                  createdDate: now,
                  status: 'Assigned',
                  updatedAt: now,
                  isSynced: false,
                );
                await _repository.createActivity(activity);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = _currentUser?.role == UserRole.teacher;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Activities'),
        actions: [
          if (isTeacher)
            IconButton(
              icon: const Icon(Icons.rate_review),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ActivityReviewPage())),
              tooltip: 'Review Submissions',
            ),
        ],
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: _showCreateActivityDialog,
              label: const Text('New Activity'),
              icon: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? const Center(child: Text('No activities found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    final isOverdue = DateTime.parse(activity.dueDate).isBefore(DateTime.now()) && activity.status == 'Assigned';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: Text(activity.activityTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activity.instructions, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 14, color: isOverdue ? Colors.red : Colors.grey),
                                const SizedBox(width: 4),
                                Text('Due: ${activity.dueDate}', style: TextStyle(color: isOverdue ? Colors.red : Colors.grey, fontSize: 12)),
                                const Spacer(),
                                _buildStatusBadge(activity.status, isOverdue),
                              ],
                            ),
                          ],
                        ),
                        onTap: () async {
                          if (isTeacher) {
                             _showActivityDetails(activity);
                          } else {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ActivitySubmissionPage(activity: activity)),
                            );
                            if (result == true) _loadData();
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _showActivityDetails(ActivityModel activity) {
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: Text(activity.activityTitle),
         content: Text(activity.instructions),
         actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
       ),
     );
  }

  Widget _buildStatusBadge(String status, bool isOverdue) {
    Color color = Colors.blue;
    String label = status;
    if (isOverdue) {
      color = Colors.red;
      label = 'Overdue';
    } else if (status == 'Completed') {
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}
