import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../auth/data/auth_repository_impl.dart';

class HomeActivitiesPage extends StatefulWidget {
  const HomeActivitiesPage({super.key});

  @override
  State<HomeActivitiesPage> createState() => _HomeActivitiesPageState();
}

class _HomeActivitiesPageState extends State<HomeActivitiesPage> {
  List<Map<String, dynamic>> _activities = [];
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
      final data = await DatabaseHelper.instance.getHomeActivitiesByTeacher(teacher.id!);
      setState(() {
        _activities = data;
        _isLoading = false;
      });
    }
  }

  void _showAssignDialog() async {
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    if (teacher == null) return;

    final children = await DatabaseHelper.instance.readChildrenByTeacher(teacher.id!);
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
                    final isPending = activity['status'] == 'Pending';

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPending ? Colors.orange : Colors.green,
                          child: Icon(
                            isPending ? Icons.pending_actions : Icons.check_circle,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(activity['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Child: ${activity['child_name']}'),
                            Text(activity['description']),
                          ],
                        ),
                        trailing: Text(activity['date_assigned']),
                      ),
                    );
                  },
                ),
    );
  }
}

class _AssignActivitySheet extends StatefulWidget {
  final List<ChildModel> children;
  final VoidCallback onSaved;
  const _AssignActivitySheet({required this.children, required this.onSaved});

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
    
    await DatabaseHelper.instance.createHomeActivity(
      teacher!.id!,
      _selectedChild!.id!,
      _titleController.text,
      _descController.text,
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
            initialValue: _selectedChild,
            decoration: const InputDecoration(labelText: 'Select Child', border: OutlineInputBorder()),
            items: widget.children.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
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
