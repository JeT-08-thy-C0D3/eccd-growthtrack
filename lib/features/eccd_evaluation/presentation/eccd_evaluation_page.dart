import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import 'eccd_assessment_form.dart';

class EccdEvaluationPage extends StatefulWidget {
  const EccdEvaluationPage({super.key});

  @override
  State<EccdEvaluationPage> createState() => _EccdEvaluationPageState();
}

class _EccdEvaluationPageState extends State<EccdEvaluationPage> {
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
      appBar: AppBar(title: const Text('ECCD Evaluations')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? const Center(child: Text('No children registered. Register a child first.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _children.length,
                  itemBuilder: (context, index) {
                    final child = _children[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(child.firstName[0].toUpperCase()),
                        ),
                        title: Text('${child.firstName} ${child.lastName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Gender: ${child.gender} | DOB: ${child.birthDate}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EccdAssessmentForm(child: child),
                            ),
                          );
                          _loadChildren(); // Refresh if needed
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
