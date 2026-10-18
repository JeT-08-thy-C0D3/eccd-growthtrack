import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
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
  
  String _selectedAssistance = 'Independent';
  bool _isSubmitting = false;
  ActivitySubmissionModel? _existingSubmission;
  XFile? _selectedEvidence;
  String? _selectedEvidenceType;

  final List<String> _assistanceLevels = [
    'Independent',
    'Minimal Assistance',
    'Moderate Assistance',
    'Full Assistance',
  ];

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
        _selectedAssistance = submission.assistanceLevel;
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
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final submission = ActivitySubmissionModel(
        activityId: widget.activity.id!,
        childId: widget.activity.childId,
        parentNote: _noteController.text,
        assistanceLevel: _selectedAssistance,
        submissionDate: now,
        reviewStatus: 'Pending',
        updatedAt: now,
        isSynced: false,
      );

      final submissionId = await _repository.submitActivity(submission);
      if (_selectedEvidence != null && _selectedEvidenceType != null) {
        await _repository.uploadSubmissionEvidence(
          submissionId: submissionId,
          filePath: _selectedEvidence!.path,
          mediaType: _selectedEvidenceType!,
        );
      }
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

  Future<void> _pickEvidence(ImageSource source, {required bool isVideo}) async {
    final picker = ImagePicker();
    final file = isVideo
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() {
      _selectedEvidence = file;
      _selectedEvidenceType = isVideo ? 'video' : 'image';
    });
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
            const Text('Assistance Provided', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedAssistance,
              decoration: const InputDecoration(
                labelText: 'Level of Assistance',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.help_outline),
              ),
              items: _assistanceLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: isSubmitted ? null : (val) => setState(() => _selectedAssistance = val!),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _noteController,
              maxLines: 5,
              enabled: !isSubmitted,
              decoration: const InputDecoration(
                labelText: 'Activity Narrative / Parent Notes',
                border: OutlineInputBorder(),
                hintText: 'Describe how the child performed the activity...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            if (!isSubmitted) ...[
              Text('Optional evidence', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Add one photo or video of the child completing the activity. It will be uploaded to Supabase Storage.'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickEvidence(ImageSource.gallery, isVideo: false),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Add photo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickEvidence(ImageSource.gallery, isVideo: true),
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Add video'),
                  ),
                ],
              ),
              if (_selectedEvidence != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_selectedEvidenceType == 'video' ? Icons.videocam : Icons.image),
                  title: Text(_selectedEvidence!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${_selectedEvidenceType == 'video' ? 'Video' : 'Photo'} ready to upload'),
                  trailing: IconButton(
                    tooltip: 'Remove evidence',
                    onPressed: () => setState(() {
                      _selectedEvidence = null;
                      _selectedEvidenceType = null;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ] else if (_existingSubmission?.evidenceUrl != null) ...[
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.cloud_done_outlined),
                title: Text('Evidence uploaded to secure storage'),
              ),
            ],
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
