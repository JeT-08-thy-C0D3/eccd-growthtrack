import 'package:flutter/material.dart';
import '../../../shared/models/child_model.dart';
import '../data/triangulation_repository_impl.dart';
import '../domain/triangulation_model.dart';

class TriangulationHistoryPage extends StatefulWidget {
  final ChildModel child;
  const TriangulationHistoryPage({super.key, required this.child});

  @override
  State<TriangulationHistoryPage> createState() => _TriangulationHistoryPageState();
}

class _TriangulationHistoryPageState extends State<TriangulationHistoryPage> {
  final _repository = TriangulationRepositoryImpl();
  List<TriangulationModel> _history = [];
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
      appBar: AppBar(title: Text('Triangulation: ${widget.child.firstName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No analysis history found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final color = _getStatusColor(item.developmentStatus);

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
                                Text(
                                  item.generatedDate,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    item.developmentStatus,
                                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            const Text('Triangulated Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(item.triangulatedSummary),
                            const SizedBox(height: 16),
                            _buildMiniSection('Teacher Input', item.teacherAssessmentSummary),
                            _buildMiniSection('Parent Input', item.parentFeedbackSummary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'On Track': return Colors.green;
      case 'Needs Monitoring': return Colors.orange;
      case 'Needs Intervention': return Colors.red;
      default: return Colors.blue;
    }
  }

  Widget _buildMiniSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          Text(content, style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
