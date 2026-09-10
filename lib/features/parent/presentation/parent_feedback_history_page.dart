import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/parent_feedback_repository.dart';
import '../domain/parent_feedback_model.dart';
import 'parent_feedback_page.dart';

class ParentFeedbackHistoryPage extends StatefulWidget {
  const ParentFeedbackHistoryPage({super.key});

  @override
  State<ParentFeedbackHistoryPage> createState() => _ParentFeedbackHistoryPageState();
}

class _ParentFeedbackHistoryPageState extends State<ParentFeedbackHistoryPage> {
  final _repository = ParentFeedbackRepositoryImpl();
  List<ParentFeedbackModel> _history = [];
  List<ChildModel> _children = [];
  ChildModel? _filterChild;
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
      _children = await DatabaseHelper.instance.readChildrenByParent(user.id!);
      if (_children.isNotEmpty) {
        _filterChild = _children.first;
        await _loadHistory();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadHistory() async {
    if (_filterChild == null) return;
    final data = await _repository.getFeedbackHistory(_filterChild!.childId);
    setState(() {
      _history = data;
      _isLoading = false;
    });
  }

  void _deleteFeedback(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this feedback?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.deleteFeedback(id);
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_children.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: DropdownButtonFormField<ChildModel>(
                      initialValue: _filterChild,
                      decoration: const InputDecoration(labelText: 'Filter by Child', border: OutlineInputBorder()),
                      items: _children.map((c) => DropdownMenuItem(value: c, child: Text("${c.firstName} ${c.lastName}"))).toList(),
                      onChanged: (val) {
                        setState(() => _filterChild = val);
                        _loadHistory();
                      },
                    ),
                  ),
                Expanded(
                  child: _history.isEmpty
                      ? const Center(child: Text('No feedback records found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final item = _history[index];
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
                                        Text(item.submissionDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                              onPressed: () async {
                                                final result = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (context) => ParentFeedbackPage(feedback: item)),
                                                );
                                                if (result == true) _loadHistory();
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                              onPressed: () => _deleteFeedback(item.id!),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    _buildInfoText('Observation:', item.parentObservation),
                                    const SizedBox(height: 8),
                                    _buildInfoText('Assistance Level:', item.assistanceLevel, color: Colors.blue),
                                    if (item.notes.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildInfoText('Notes:', item.notes),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoText(String label, String content, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(content, style: TextStyle(fontSize: 14, color: color)),
      ],
    );
  }
}
