import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/activity_repository.dart';
import '../domain/activity_model.dart';
import '../../../core/utils/validators.dart';
import 'activity_submission_page.dart';
import 'activity_review_page.dart';

class ActivityManagementPage extends StatefulWidget {
  const ActivityManagementPage({super.key});

  @override
  State<ActivityManagementPage> createState() => _ActivityManagementPageState();
}

class _ActivityManagementPageState extends State<ActivityManagementPage> {
  final ActivityRepository _repository = ActivityRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  List<ActivityModel> _allActivities = [];
  List<ActivityModel> _filteredActivities = [];
  List<ChildModel> _children = [];
  UserModel? _currentUser;
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';
  String _sortBy = 'Due Date Newest First';
  bool _isLoading = true;

  final List<String> _statusFilters = ['All', 'Assigned', 'Completed', 'Overdue'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _currentUser = await AuthRepositoryImpl().getCurrentUser();
    
    if (_currentUser?.role == UserRole.teacher) {
      _allActivities = await _repository.getAllActivities();
      _children = await DatabaseHelper.instance.getAllChildren();
    } else if (_currentUser?.role == UserRole.parent) {
      final children = await DatabaseHelper.instance.readChildrenByParent(_currentUser!.uid);
      if (children.isNotEmpty) {
        _allActivities = await _repository.getActivitiesForChild(children.first.childId);
      }
    }

    _applyFilterAndSort();
    setState(() => _isLoading = false);
  }

  void _applyFilterAndSort() {
    setState(() {
      final q = _searchQuery.toLowerCase();
      _filteredActivities = _allActivities.where((activity) {
        final title = activity.activityTitle.toLowerCase();
        final instructions = activity.instructions.toLowerCase();
        final childId = activity.childId.toLowerCase();

        final isOverdue = DateTime.tryParse(activity.dueDate)?.isBefore(DateTime.now()) ?? false;
        final currentStatus = (isOverdue && activity.status == 'Assigned') ? 'Overdue' : activity.status;

        final matchesSearch = title.contains(q) || instructions.contains(q) || childId.contains(q);
        final matchesStatus = _selectedStatusFilter == 'All' ||
            currentStatus.toLowerCase() == _selectedStatusFilter.toLowerCase();

        return matchesSearch && matchesStatus;
      }).toList();

      _filteredActivities.sort((a, b) {
        final dateA = a.dueDate;
        final dateB = b.dueDate;
        switch (_sortBy) {
          case 'Title A-Z':
            return a.activityTitle.toLowerCase().compareTo(b.activityTitle.toLowerCase());
          case 'Due Date Oldest First':
            return dateA.compareTo(dateB);
          case 'Due Date Newest First':
          default:
            return dateB.compareTo(dateA);
        }
      });
    });
  }

  void _showCreateActivityDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final instructionsController = TextEditingController();
    final maxScoreController = TextEditingController(text: '20');
    ChildModel? selectedChild = _children.isNotEmpty ? _children.first : null;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Home Activity'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ChildModel>(
                    initialValue: selectedChild,
                    decoration: const InputDecoration(labelText: 'Assign to Child'),
                    items: _children.map((c) => DropdownMenuItem(value: c, child: Text("${c.firstName} ${c.lastName} (${c.childId})"))).toList(),
                    onChanged: (val) => setDialogState(() => selectedChild = val),
                    validator: (val) => val == null ? 'Please select a child' : null,
                  ),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Activity Title'),
                    validator: (v) => Validators.validateRequired(v, 'Activity Title'),
                  ),
                  TextFormField(
                    controller: instructionsController,
                    decoration: const InputDecoration(labelText: 'Instructions'),
                    maxLines: 3,
                    validator: (v) => Validators.validateRequired(v, 'Instructions'),
                  ),
                  TextFormField(
                    controller: maxScoreController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Score (e.g. 20)',
                      helperText: 'Maximum points possible for this activity',
                    ),
                    validator: (v) {
                      final req = Validators.validateRequired(v, 'Max Score');
                      if (req != null) return req;
                      final score = int.tryParse(v!.trim());
                      if (score == null || score <= 0 || score > 100) {
                        return 'Score must be a number between 1 and 100';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  if (selectedChild == null) return;
                  final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
                  final maxScore = int.tryParse(maxScoreController.text.trim()) ?? 20;

                  final activity = ActivityModel(
                    childId: selectedChild!.childId,
                    activityTitle: titleController.text.trim(),
                    instructions: instructionsController.text.trim(),
                    dueDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                    assignedBy: _currentUser?.name ?? 'Teacher',
                    createdDate: now,
                    status: 'Assigned',
                    updatedAt: now,
                    isSynced: false,
                    maxScore: maxScore,
                  );
                  await _repository.createActivity(activity);
                  if (!mounted) return;
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search activities by Child ID, Title, or Instructions...',
              leading: const Icon(Icons.search),
              onChanged: (val) {
                _searchQuery = val;
                _applyFilterAndSort();
              },
            ),
          ),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredActivities.isEmpty
                    ? const Center(child: Text('No matching activities found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredActivities.length,
                        itemBuilder: (context, index) {
                          final activity = _filteredActivities[index];
                          final isOverdue = DateTime.tryParse(activity.dueDate)?.isBefore(DateTime.now()) ?? false && activity.status == 'Assigned';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              title: Text(activity.activityTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(activity.instructions, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('Child ID: ${activity.childId} | Max Score: ${activity.maxScore} pts', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18),
          const SizedBox(width: 8),
          const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusFilters.map((status) {
                  final isSelected = _selectedStatusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(status == 'All' ? 'All Status' : status, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedStatusFilter = status;
                            _applyFilterAndSort();
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          DropdownButton<String>(
            value: _sortBy,
            underline: const SizedBox(),
            icon: const Icon(Icons.sort, size: 20),
            items: ['Due Date Newest First', 'Due Date Oldest First', 'Title A-Z']
                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _sortBy = val;
                  _applyFilterAndSort();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  void _showActivityDetails(ActivityModel activity) {
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: Text(activity.activityTitle),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text('Child ID: ${activity.childId}', style: const TextStyle(fontWeight: FontWeight.bold)),
             Text('Max Score: ${activity.maxScore} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
             const SizedBox(height: 8),
             Text(activity.instructions),
           ],
         ),
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
