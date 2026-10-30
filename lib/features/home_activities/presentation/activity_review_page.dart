import 'package:flutter/material.dart';
import '../data/activity_repository.dart';
import '../../../core/utils/validators.dart';

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
    final formKey = GlobalKey<FormState>();
    final reviewController = TextEditingController(text: submission['teacher_review'] as String? ?? '');
    final maxScore = (submission['max_score'] as int?) ?? 20;
    final scoreController = TextEditingController(
      text: (submission['score'] != null) ? submission['score'].toString() : maxScore.toString(),
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review: ${submission['activity_title']}'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Child: ${submission['first_name']} ${submission['last_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Assistance Level: ${submission['assistance_level']}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                const Text('Parent Observation Note:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(submission['parent_note'] as String? ?? 'No parent notes provided.'),
                const Divider(height: 24),
                TextFormField(
                  controller: scoreController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Score Awarded (Max: $maxScore pts)',
                    border: const OutlineInputBorder(),
                    helperText: 'Award score between 0 and $maxScore',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Score is required';
                    final s = int.tryParse(v.trim());
                    if (s == null || s < 0 || s > maxScore) {
                      return 'Enter a valid score between 0 and $maxScore';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reviewController,
                  decoration: const InputDecoration(
                    labelText: 'Teacher Feedback / Review',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    hintText: 'Enter teacher observations or feedback...',
                  ),
                  maxLines: 3,
                  validator: (v) => Validators.validateRequired(v, 'Teacher Review Feedback'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final score = int.tryParse(scoreController.text.trim());
                await _repository.reviewSubmission(submission['id'], reviewController.text.trim(), 'Rejected', score: score);
                if (mounted) {
                  Navigator.pop(context);
                  _loadSubmissions();
                }
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final score = int.tryParse(scoreController.text.trim());
                await _repository.reviewSubmission(submission['id'], reviewController.text.trim(), 'Approved', score: score);
                if (mounted) {
                  Navigator.pop(context);
                  _loadSubmissions();
                }
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
                    final score = sub['score'];
                    final maxScore = sub['max_score'] ?? 20;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.description)),
                        title: Text(sub['activity_title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Child: ${sub['first_name']} ${sub['last_name']} | Status: $status'),
                            if (score != null) ...[
                              const SizedBox(height: 2),
                              Text('Score: $score / $maxScore pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ],
                        ),
                        trailing: status == 'Pending' ? const Icon(Icons.pending_actions, color: Colors.orange) : const Icon(Icons.check_circle, color: Colors.green),
                        onTap: () => _showReviewDialog(sub),
                      ),
                    );
                  },
                ),
    );
  }
}
