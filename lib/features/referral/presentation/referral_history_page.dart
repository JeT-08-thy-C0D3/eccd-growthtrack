import 'package:flutter/material.dart';
import '../../../shared/models/child_model.dart';
import '../data/referral_repository.dart';
import '../domain/referral_model.dart';

class ReferralHistoryPage extends StatefulWidget {
  final ChildModel child;
  const ReferralHistoryPage({super.key, required this.child});

  @override
  State<ReferralHistoryPage> createState() => _ReferralHistoryPageState();
}

class _ReferralHistoryPageState extends State<ReferralHistoryPage> {
  final ReferralRepository _repository = ReferralRepositoryImpl();
  List<ReferralModel> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await _repository.getReferralsByChild(widget.child.childId);
    setState(() {
      _history = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('History: ${widget.child.firstName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No referral history for this child.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final color = _getStatusColor(item.status);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(item.referralDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text(item.status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text('Concern: ${item.concern}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(item.description),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.update, size: 16, color: Colors.blueGrey),
                                const SizedBox(width: 4),
                                Text('Follow-up: ${item.followUpDate}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            if (item.followUpNotes != null && item.followUpNotes!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text('Follow-up Notes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(item.followUpNotes!, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                            ],
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
      case 'Pending': return Colors.orange;
      case 'Referred': return Colors.blue;
      case 'For Follow-Up': return Colors.purple;
      case 'Completed': return Colors.green;
      case 'Closed': return Colors.grey;
      default: return Colors.black;
    }
  }
}
