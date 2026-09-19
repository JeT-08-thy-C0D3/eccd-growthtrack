import 'package:flutter/material.dart';
import '../data/activity_repository.dart';
import '../domain/activity_model.dart';
import '../../../shared/models/child_model.dart';
import '../../auth/data/auth_repository_impl.dart';

class HomeActivitiesPage extends StatefulWidget {
  const HomeActivitiesPage({super.key});

  @override
  State<HomeActivitiesPage> createState() => _HomeActivitiesPageState();
}

class _HomeActivitiesPageState extends State<HomeActivitiesPage> {
  final ActivityRepository _repository = ActivityRepositoryImpl();
  List<ActivityModel> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    if (teacher != null) {
      final data = await _repository.getHomeActivitiesByTeacher(teacher.id!);
      setState(() {
        _activities = data;
        _isLoading = false;
      });
    }
  }

  void _showAssignDialog() async {
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    if (teacher == null) return;

    final children = await _repository.getTeacherChildren(teacher.id!);
    if (children.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Register a child first to assign activities.')),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AssignActivitySheet(
        children: children,
        repository: _repository,
        onSaved: () {
          Navigator.pop(context);
          _loadActivities();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Activities')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAssignDialog,
        icon: const Icon(Icons.add),
        label: const Text('Assign Activity'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? const Center(child: Text('No home activities assigned yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    final isPending = activity.status == 'Assigned';

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPending ? Colors.orange : Colors.green,
                          child: Icon(
                            isPending ? Icons.pending_actions : Icons.check_circle,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(activity.activityTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Due: ${activity.dueDate}'),
                            Text(activity.instructions),
                          ],
                        ),
                        trailing: Text(activity.status),
                      ),
                    );
                  },
                ),
    );
  }
}

class _AssignActivitySheet extends StatefulWidget {
  final List<ChildModel> children;
  final ActivityRepository repository;
  final VoidCallback onSaved;
  const _AssignActivitySheet({
    required this.children,
    required this.repository,
    required this.onSaved,
  });

  @override
  State<_AssignActivitySheet> createState() => _AssignActivitySheetState();
}

class _AssignActivitySheetState extends State<_AssignActivitySheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  ChildModel? _selectedChild;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedChild = widget.children.first;
  }

  void _submit() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty) return;
    
    setState(() => _isSaving = true);
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    
    await widget.repository.createHomeActivity(
      teacherId: teacher!.id!,
      childId: _selectedChild!.id!,
      title: _titleController.text,
      instructions: _descController.text,
    );

    setState(() => _isSaving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Assign Activity to Parent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<ChildModel>(
            value: _selectedChild,
            decoration: const InputDecoration(labelText: 'Select Child', border: OutlineInputBorder()),
            items: widget.children.map((c) => DropdownMenuItem(value: c, child: Text("${c.firstName} ${c.lastName}"))).toList(),
            onChanged: (val) => setState(() => _selectedChild = val),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Activity Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Instructions for Parent', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isSaving ? const CircularProgressIndicator() : const Text('Assign to Parent'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
