import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import 'child_summary_report.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<ChildModel> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    if (teacher != null) {
      final children = await DatabaseHelper.instance.readChildrenByTeacher(teacher.id!);
      setState(() {
        _children = children;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress Reports')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? const Center(child: Text('No children registered yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _children.length,
                  itemBuilder: (context, index) {
                    final child = _children[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.description)),
                        title: Text("${child.firstName} ${child.lastName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('View developmental summary & attendance'),
                        trailing: const Icon(Icons.analytics_outlined, color: Colors.blue),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChildSummaryReport(child: child),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
