import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/validators.dart';
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
  static const _maxImageBytes = 5 * 1024 * 1024;
  static const _maxVideoBytes = 40 * 1024 * 1024;

  final ActivityRepository _repository = ActivityRepositoryImpl();
  final _noteController = TextEditingController();

  String _selectedAssistance = 'Independent';
  bool _isSubmitting = false;
  ActivitySubmissionModel? _existingSubmission;
  Uint8List? _selectedEvidenceBytes;
  String? _selectedEvidenceName;
  String? _selectedEvidenceType;
  String? _selectedEvidenceContentType;

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
    // Repair records submitted before the web status update was available.
    // Their proof is already stored, so they must be shown as completed.
    if (submission?.evidenceUrl?.trim().isNotEmpty == true &&
        widget.activity.status != 'Completed') {
      await _repository.updateActivityStatus(widget.activity.id!, 'Completed');
    }
    if (!mounted) return;
    if (submission != null) {
      setState(() {
        _existingSubmission = submission;
        _noteController.text = submission.parentNote;
        _selectedAssistance = submission.assistanceLevel;
      });
    }
  }

  void _submit() async {
    final hasUploadedEvidence =
        _existingSubmission?.evidenceUrl?.trim().isNotEmpty ?? false;
    if (_selectedEvidenceBytes == null && !hasUploadedEvidence) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A photo or video proof is required by the teacher before submitting.',
          ),
        ),
      );
      return;
    }

    final noteError = Validators.validateAppropriateText(
      _noteController.text,
      'Activity Narrative / Parent Notes',
      required: true,
    );
    if (noteError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(noteError)));
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
        teacherUid: widget.activity.assignedTeacherUid,
        parentUid: widget.activity.parentUid,
      );

      final submissionId =
          _existingSubmission?.id ??
          await _repository.submitActivity(submission);
      if (_existingSubmission == null && mounted) {
        setState(
          () => _existingSubmission = submission.copyWith(id: submissionId),
        );
      }
      if (_selectedEvidenceBytes != null &&
          _selectedEvidenceType != null &&
          _selectedEvidenceName != null) {
        final evidenceUrl = await _repository.uploadSubmissionEvidenceBytes(
          submissionId: submissionId,
          bytes: _selectedEvidenceBytes!,
          fileName: _selectedEvidenceName!,
          mediaType: _selectedEvidenceType!,
          contentType: _selectedEvidenceContentType,
        );
        if (evidenceUrl == null) {
          throw StateError(
            'The required proof could not be uploaded to secure storage. Please try again.',
          );
        }
      }
      await _repository.updateActivityStatus(widget.activity.id!, 'Completed');

      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity submitted for review!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _pickEvidence(
    ImageSource source, {
    required bool isVideo,
  }) async {
    final picker = ImagePicker();
    final file = isVideo
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!_isWithinEvidenceSizeLimit(
      bytes.length,
      isVideo ? 'video' : 'image',
    )) {
      return;
    }
    setState(() {
      _selectedEvidenceBytes = bytes;
      _selectedEvidenceName = file.name;
      _selectedEvidenceType = isVideo ? 'video' : 'image';
      _selectedEvidenceContentType = _contentTypeFor(
        file.name,
        isVideo: isVideo,
      );
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'mp4',
        'pdf',
        'doc',
        'docx',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to read the selected file. Please try again.'),
        ),
      );
      return;
    }
    final extension = file.extension?.toLowerCase() ?? '';
    final mediaType = extension == 'mp4'
        ? 'video'
        : const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? 'image'
        : 'file';
    if (!_isWithinEvidenceSizeLimit(bytes.length, mediaType)) return;
    setState(() {
      _selectedEvidenceBytes = bytes;
      _selectedEvidenceName = file.name;
      _selectedEvidenceType = mediaType;
      _selectedEvidenceContentType = _contentTypeFor(file.name);
    });
  }

  bool _isWithinEvidenceSizeLimit(int byteLength, String mediaType) {
    final maxBytes = mediaType == 'image' ? _maxImageBytes : _maxVideoBytes;
    if (byteLength <= maxBytes) return true;

    final typeLabel = mediaType == 'image' ? 'Images' : 'Videos and files';
    final limitLabel = mediaType == 'image' ? '5 MB' : '40 MB';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$typeLabel must be $limitLabel or smaller.')),
    );
    return false;
  }

  String _contentTypeFor(String fileName, {bool isVideo = false}) {
    final extension = fileName.split('.').last.toLowerCase();
    if (isVideo || extension == 'mp4') return 'video/mp4';
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUploadedEvidence =
        _existingSubmission?.evidenceUrl?.trim().isNotEmpty ?? false;
    final isSubmitted = _existingSubmission != null && hasUploadedEvidence;

    return Scaffold(
      appBar: AppBar(title: const Text('Submit Activity')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.activity.activityTitle,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
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
                      Text(
                        'This activity has been submitted.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Text(
              'Assistance Provided',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedAssistance,
              decoration: const InputDecoration(
                labelText: 'Level of Assistance',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.help_outline),
              ),
              items: _assistanceLevels
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: isSubmitted
                  ? null
                  : (val) => setState(() => _selectedAssistance = val!),
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
              Text(
                'Required photo or video proof',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload a photo, MP4 video, or supporting file. Proof is required before submission and is stored securely in Supabase Storage.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _pickEvidence(ImageSource.gallery, isVideo: false),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Add photo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _pickEvidence(ImageSource.gallery, isVideo: true),
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Add video'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('Add file'),
                  ),
                ],
              ),
              if (_selectedEvidenceBytes != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _selectedEvidenceType == 'video'
                        ? Icons.videocam
                        : _selectedEvidenceType == 'image'
                        ? Icons.image
                        : Icons.insert_drive_file_outlined,
                  ),
                  title: Text(
                    _selectedEvidenceName ?? 'Selected evidence',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_selectedEvidenceType == 'video'
                        ? 'Video'
                        : _selectedEvidenceType == 'image'
                        ? 'Image'
                        : 'File'} ready to upload',
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove evidence',
                    onPressed: () => setState(() {
                      _selectedEvidenceBytes = null;
                      _selectedEvidenceName = null;
                      _selectedEvidenceType = null;
                      _selectedEvidenceContentType = null;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
              if (_selectedEvidenceBytes == null)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Proof is required to submit this activity.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ] else if (_existingSubmission?.evidenceUrl != null) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _existingSubmission?.evidenceMediaType == 'video'
                      ? Icons.videocam_outlined
                      : _existingSubmission?.evidenceMediaType == 'image'
                      ? Icons.image_outlined
                      : Icons.insert_drive_file_outlined,
                ),
                title: Text(
                  _existingSubmission?.evidenceFileName?.trim().isNotEmpty ==
                          true
                      ? _existingSubmission!.evidenceFileName!
                      : 'Submitted proof',
                ),
                subtitle: const Text('Uploaded and submitted for review'),
                trailing: TextButton.icon(
                  onPressed: _openSubmittedProof,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (!isSubmitted)
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: const Icon(Icons.send),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Completion',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            if (isSubmitted && _existingSubmission?.score != null) ...[
              const SizedBox(height: 32),
              Builder(
                builder: (context) {
                  final score = _existingSubmission!.score!;
                  final percentage = widget.activity.maxScore > 0
                      ? (score / widget.activity.maxScore) * 100
                      : 0.0;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Teacher score: $score / ${widget.activity.maxScore} (${percentage.toStringAsFixed(1)}%)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  );
                },
              ),
            ],
            if (isSubmitted && _existingSubmission?.teacherReview != null) ...[
              const SizedBox(height: 32),
              const Text(
                'Teacher Comments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _existingSubmission!.teacherReview!,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSubmittedProof() async {
    final submission = _existingSubmission;
    final url = submission?.evidenceUrl?.trim();
    if (submission?.id == null || url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted proof is not available.')),
      );
      return;
    }

    try {
      final refreshedUrl = await _repository.refreshSubmissionEvidenceUrl(
        submissionId: submission!.id!,
        expiredUrl: url,
        mediaType: submission.evidenceMediaType ?? 'file',
        fileName: submission.evidenceFileName,
      );
      if (!mounted) return;
      setState(
        () => _existingSubmission = submission.copyWith(
          evidenceUrl: refreshedUrl,
        ),
      );
      final opened = await launchUrl(
        Uri.parse(refreshedUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the submitted proof.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to refresh proof link: $error')),
        );
      }
    }
  }
}
