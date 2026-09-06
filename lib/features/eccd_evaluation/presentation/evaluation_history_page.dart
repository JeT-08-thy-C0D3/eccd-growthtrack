import 'package:flutter/material.dart';
import '../../../shared/models/child_model.dart';
import '../data/evaluation_repository.dart';

class EvaluationHistoryPage extends StatefulWidget {
  final ChildModel child;
  const EvaluationHistoryPage({super.key, required this.child});

  @override
  State<EvaluationHistoryPage> createState() => _EvaluationHistoryPageState();
}

class _EvaluationHistoryPageState extends State<EvaluationHistoryPage> {
  final EvaluationRepository _repository = EvaluationRepositoryImpl();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await _repository.getHistory(widget.child.childId);
    setState(() {
      _history = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Evaluation History: ${widget.child.firstName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No evaluations found for this child.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final record = _history[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  record['domain'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                Text(
                                  record['evaluation_date'],
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              children: [
                                const Text('Score: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('${record['score']} pts'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('Remarks:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(record['remarks'] ?? 'No remarks'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
