import 'package:flutter/material.dart';
import '../../../shared/models/child_model.dart';
import '../data/development_summary_repository.dart';
import '../domain/development_summary_model.dart';

class DevelopmentSummaryHistoryPage extends StatefulWidget {
  final ChildModel child;
  const DevelopmentSummaryHistoryPage({super.key, required this.child});

  @override
  State<DevelopmentSummaryHistoryPage> createState() => _DevelopmentSummaryHistoryPageState();
}

class _DevelopmentSummaryHistoryPageState extends State<DevelopmentSummaryHistoryPage> {
  final DevelopmentSummaryRepository _repository = DevelopmentSummaryRepositoryImpl();
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
      appBar: AppBar(title: Text('Summaries: ${widget.child.firstName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No summary history found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = DevelopmentSummaryModel.fromMap(_history[index]);
                    final isApproved = item.approvalStatus == 'Approved';

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
                                Text(item.createdDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                _buildStatusBadge(item.approvalStatus),
                              ],
                            ),
                            const Divider(height: 24),
                            const Text('Development Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(item.developmentSummary),
                            const SizedBox(height: 12),
                            const Text('Strength Areas:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            Text(item.strengthAreas),
                            const SizedBox(height: 12),
                            const Text('Home Activities:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                            Text(item.suggestedHomeActivities),
                            if (isApproved) ...[
                              const Divider(height: 32),
                              Text('Approved by ${item.approvedBy} on ${item.approvedDate}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    if (status == 'Approved') color = Colors.green;
    if (status == 'Rejected') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
