import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/activity_repository.dart';
import '../domain/activity_model.dart';
import '../domain/activity_submission_model.dart';

class ActivitySubmissionPage extends StatefulWidget {
  final ActivityModel activity;
  const ActivitySubmissionPage({super.key, required this.activity});

  @override
  State<ActivitySubmissionPage> createState() => _ActivitySubmissionPageState();
}

class _ActivitySubmissionPageState extends State<ActivitySubmissionPage> {
  final ActivityRepository _repository = ActivityRepositoryImpl();
  final _noteController = TextEditingController();
  final _evidenceController = TextEditingController(text: 'mock_evidence_path/activity_photo.jpg');
  bool _isSubmitting = false;
  ActivitySubmissionModel? _existingSubmission;

  @override
  void initState() {
    super.initState();
    _checkExistingSubmission();
  }

  Future<void> _checkExistingSubmission() async {
    final submission = await _repository.getSubmission(widget.activity.id!);
    if (submission != null) {
      setState(() {
        _existingSubmission = submission;
        _noteController.text = submission.parentNote;
      });
    }
  }

  void _submit() async {
    if (_noteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a note.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final submission = ActivitySubmissionModel(
        activityId: widget.activity.id!,
        childId: widget.activity.childId,
        evidencePath: _evidenceController.text,
        parentNote: _noteController.text,
        submissionDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        reviewStatus: 'Pending',
      );

      await _repository.submitActivity(submission);
      await _repository.updateActivityStatus(widget.activity.id!, 'Completed');

      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity submitted for review!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitted = _existingSubmission != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Submit Activity')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.activity.activityTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.activity.instructions),
            const Divider(height: 48),
            if (isSubmitted) ...[
              const Card(
                color: Colors.greenAccent,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 12),
                      Text('This activity has been submitted.', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Text('Activity Evidence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                    Text('Simulated Image Upload', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _noteController,
              maxLines: 4,
              enabled: !isSubmitted,
              decoration: const InputDecoration(
                labelText: 'Notes to Teacher',
                border: OutlineInputBorder(),
                hintText: 'How did your child find this activity?',
              ),
            ),
            const SizedBox(height: 32),
            if (!isSubmitted)
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: const Icon(Icons.send),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Completion'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            if (isSubmitted && _existingSubmission?.teacherReview != null) ...[
               const SizedBox(height: 32),
               const Text('Teacher Feedback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
               const SizedBox(height: 8),
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                 child: Text(_existingSubmission!.teacherReview!, style: const TextStyle(fontStyle: FontStyle.italic)),
               ),
            ]
          ],
        ),
      ),
    );
  }
}
