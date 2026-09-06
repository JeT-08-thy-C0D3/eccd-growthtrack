import 'package:flutter/material.dart';
import '../data/child_repository.dart';
import '../../../shared/models/child_model.dart';
import 'child_registration_page.dart';

class ChildListPage extends StatefulWidget {
  const ChildListPage({super.key});

  @override
  State<ChildListPage> createState() => _ChildListPageState();
}

class _ChildListPageState extends State<ChildListPage> {
  final ChildRepository _repository = ChildRepositoryImpl();
  List<ChildModel> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshChildren();
  }

  Future<void> _refreshChildren() async {
    setState(() => _isLoading = true);
    final data = await _repository.getChildren();
    setState(() {
      _children = data;
      _isLoading = false;
    });
  }

  void _deleteChild(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this child profile?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.deleteChild(id);
      _refreshChildren();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Profiles'),
        actions: [
          IconButton(onPressed: _refreshChildren, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChildRegistrationPage()),
          );
          if (result == true) _refreshChildren();
        },
        label: const Text('Register Child'),
        icon: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? const Center(child: Text('No children registered yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _children.length,
                  itemBuilder: (context, index) {
                    final child = _children[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(child.firstName[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text('${child.firstName} ${child.lastName}', 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${child.childId}'),
                            Text('Age: ${child.age} | Gender: ${child.gender}'),
                            Text('Parent: ${child.parentName}'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ChildRegistrationPage(child: child)),
                                );
                                if (result == true) _refreshChildren();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteChild(child.id!),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
