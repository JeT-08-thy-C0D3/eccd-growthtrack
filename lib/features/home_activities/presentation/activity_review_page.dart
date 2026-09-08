import 'package:flutter/material.dart';
import '../data/activity_repository.dart';

class ActivityReviewPage extends StatefulWidget {
  const ActivityReviewPage({super.key});

  @override
  State<ActivityReviewPage> createState() => _ActivityReviewPageState();
}

class _ActivityReviewPageState extends State<ActivityReviewPage> {
  final ActivityRepository _repository = ActivityRepositoryImpl();
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);
    _submissions = await _repository.getAllSubmissions();
    setState(() => _isLoading = false);
  }

  void _showReviewDialog(Map<String, dynamic> submission) {
    final reviewController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review: ${submission['activity_title']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Child: ${submission['first_name']} ${submission['last_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Parent Note: ${submission['parent_note']}'),
            const Divider(height: 32),
            TextField(
              controller: reviewController,
              decoration: const InputDecoration(labelText: 'Teacher Feedback', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _repository.reviewSubmission(submission['id'], reviewController.text, 'Rejected');
              if (mounted) {
                Navigator.pop(context);
                _loadSubmissions();
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _repository.reviewSubmission(submission['id'], reviewController.text, 'Approved');
              if (mounted) {
                Navigator.pop(context);
                _loadSubmissions();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Submissions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _submissions.isEmpty
              ? const Center(child: Text('No submissions to review.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _submissions.length,
                  itemBuilder: (context, index) {
                    final sub = _submissions[index];
                    final status = sub['review_status'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.attachment)),
                        title: Text(sub['activity_title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Child: ${sub['first_name']} ${sub['last_name']} | Status: $status'),
                        trailing: status == 'Pending' ? const Icon(Icons.pending_actions, color: Colors.orange) : const Icon(Icons.check_circle, color: Colors.green),
                        onTap: () => _showReviewDialog(sub),
                      ),
                    );
                  },
                ),
    );
  }
}
