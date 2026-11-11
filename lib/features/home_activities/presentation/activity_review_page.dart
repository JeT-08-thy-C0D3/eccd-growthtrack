import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/activity_repository.dart';
import '../../../core/utils/validators.dart';

class ActivityReviewPage extends StatefulWidget {
  const ActivityReviewPage({super.key});

  @override
  State<ActivityReviewPage> createState() => _ActivityReviewPageState();
}

class _ActivityReviewPageState extends State<ActivityReviewPage> {
  final ActivityRepository _repository = ActivityRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _filteredSubmissions = [];
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedChildId = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);
    try {
      final submissions = await _repository.getAllSubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = submissions;
        _applyFilters();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredSubmissions = _submissions.where((submission) {
      final childId = submission['child_id']?.toString() ?? '';
      final childName =
          '${submission['first_name'] ?? ''} ${submission['last_name'] ?? ''}'
              .trim()
              .toLowerCase();
      final parentName = (submission['parent_name']?.toString() ?? '')
          .toLowerCase();
      final activity = (submission['activity_title']?.toString() ?? '')
          .toLowerCase();
      final status = (submission['review_status']?.toString() ?? 'Pending')
          .toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          childId.toLowerCase().contains(query) ||
          childName.contains(query) ||
          parentName.contains(query) ||
          activity.contains(query);
      final matchesStatus =
          _selectedStatus == 'All' || status == _selectedStatus.toLowerCase();
      final matchesChild =
          _selectedChildId == 'All' || childId == _selectedChildId;
      return matchesSearch && matchesStatus && matchesChild;
    }).toList();
  }

  List<Map<String, String>> get _childFilters {
    final children = <String, Map<String, String>>{};
    for (final submission in _submissions) {
      final id = submission['child_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final name =
          '${submission['first_name'] ?? 'Child'} ${submission['last_name'] ?? ''}'
              .trim();
      children[id] = {'id': id, 'name': name};
    }
    return children.values.toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showReviewDialog(Map<String, dynamic> submission) {
    final formKey = GlobalKey<FormState>();
    final reviewController = TextEditingController(
      text: submission['teacher_review'] as String? ?? '',
    );
    final maxScore = (submission['max_score'] as num?)?.toInt() ?? 20;
    final scoreController = TextEditingController(
      text: (submission['score'] != null) ? submission['score'].toString() : '',
    );
    final scoreNotifier = ValueNotifier<int?>(
      int.tryParse(scoreController.text.trim()),
    );
    final evidenceUrl = submission['evidence_url'] as String?;
    final hasEvidence = evidenceUrl?.isNotEmpty == true;

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
                Text(
                  'Child: ${submission['first_name']} ${submission['last_name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Assistance Level: ${submission['assistance_level']}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Parent Observation Note:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  submission['parent_note'] as String? ??
                      'No parent notes provided.',
                ),
                if (hasEvidence) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Parent activity evidence',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _SubmissionEvidencePreview(
                    url: evidenceUrl!,
                    mediaType: submission['evidence_media_type'] as String?,
                    fileName: submission['evidence_file_name'] as String?,
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  const _MissingEvidenceNotice(),
                ],
                const Divider(height: 24),
                TextFormField(
                  controller: scoreController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Score Awarded (Max: $maxScore pts)',
                    border: const OutlineInputBorder(),
                    helperText: 'Enter the earned score only. Percentage is calculated automatically.',
                  ),
                  onChanged: (value) {
                    scoreNotifier.value = int.tryParse(value.trim());
                  },
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Score is required';
                    }
                    final s = int.tryParse(v.trim());
                    if (s == null || s < 0 || s > maxScore) {
                      return 'Enter a valid score between 0 and $maxScore';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<int?>(
                  valueListenable: scoreNotifier,
                  builder: (context, score, _) {
                    final isValid =
                        score != null && score >= 0 && score <= maxScore;
                    final percentage = isValid
                        ? (score / maxScore) * 100
                        : null;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        percentage == null
                            ? 'Percentage will appear after entering a valid score.'
                            : 'Computed result: $score / $maxScore = ${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: percentage == null
                              ? Colors.black54
                              : Colors.blue.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reviewController,
                  decoration: const InputDecoration(
                    labelText: 'Teacher Comments',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    hintText: 'Write comments or feedback for the parent...',
                  ),
                  maxLines: 4,
                  validator: (v) => Validators.validateAppropriateText(
                    v,
                    'Teacher Review Feedback',
                    required: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: hasEvidence
                ? () async {
                    if (formKey.currentState!.validate()) {
                      final score = int.tryParse(scoreController.text.trim());
                      await _repository.reviewSubmission(
                        submission['id'],
                        reviewController.text.trim(),
                        'Rejected',
                        score: score,
                      );
                      if (!mounted || !context.mounted) return;
                      Navigator.pop(context);
                      _loadSubmissions();
                    }
                  }
                : null,
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: hasEvidence
                ? () async {
                    if (formKey.currentState!.validate()) {
                      final score = int.tryParse(scoreController.text.trim());
                      await _repository.reviewSubmission(
                        submission['id'],
                        reviewController.text.trim(),
                        'Approved',
                        score: score,
                      );
                      if (!mounted || !context.mounted) return;
                      Navigator.pop(context);
                      _loadSubmissions();
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
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
          : Column(
              children: [
                _buildFilterPanel(),
                Expanded(
                  child: _filteredSubmissions.isEmpty
                      ? Center(
                          child: Text(
                            _submissions.isEmpty
                                ? 'No completed activity submissions yet.'
                                : 'No submissions match the selected filters.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredSubmissions.length,
                          itemBuilder: (context, index) {
                            final sub = _filteredSubmissions[index];
                            final status = sub['review_status'];
                            final score = sub['score'];
                            final maxScore =
                                (sub['max_score'] as num?)?.toInt() ?? 20;
                            final percentage = score is num && maxScore > 0
                                ? (score / maxScore) * 100
                                : null;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.description),
                                ),
                                title: Text(
                                  sub['activity_title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Child: ${sub['first_name']} ${sub['last_name']} | Status: $status',
                                    ),
                                    Text(
                                      'Parent/Guardian: ${sub['parent_name'] ?? 'Parent/Guardian'}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      (sub['evidence_url'] as String?)
                                                  ?.isNotEmpty ==
                                              true
                                          ? 'Proof attached — ready for teacher review'
                                          : 'Proof missing — grading is locked',
                                      style: TextStyle(
                                        color:
                                            (sub['evidence_url'] as String?)
                                                    ?.isNotEmpty ==
                                                true
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (score != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Score: $score / $maxScore pts${percentage == null ? '' : ' (${percentage.toStringAsFixed(1)}%)'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: status == 'Pending'
                                    ? const Icon(
                                        Icons.pending_actions,
                                        color: Colors.orange,
                                      )
                                    : const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                onTap: () => _showReviewDialog(sub),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterPanel() {
    final children = _childFilters;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: .35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final search = TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search child, parent, or activity',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() {
                _searchQuery = value;
                _applyFilters();
              }),
            );
            final status = DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Review status',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const ['All', 'Pending', 'Approved', 'Rejected']
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedStatus = value ?? 'All';
                _applyFilters();
              }),
            );
            final child = DropdownButtonFormField<String>(
              initialValue: _selectedChildId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Child',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: 'All',
                  child: Text('All children'),
                ),
                ...children.map(
                  (item) => DropdownMenuItem(
                    value: item['id'],
                    child: Text(
                      '${item['name']} (${item['id']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() {
                _selectedChildId = value ?? 'All';
                _applyFilters();
              }),
            );
            if (constraints.maxWidth < 680) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  status,
                  const SizedBox(height: 10),
                  child,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                SizedBox(width: 160, child: status),
                const SizedBox(width: 12),
                SizedBox(width: 250, child: child),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SubmissionEvidencePreview extends StatelessWidget {
  const _SubmissionEvidencePreview({
    required this.url,
    this.mediaType,
    this.fileName,
  });

  final String url;
  final String? mediaType;
  final String? fileName;

  bool get _isVideo => mediaType == 'video';
  bool get _isFile => mediaType == 'file';

  @override
  Widget build(BuildContext context) {
    if (_isVideo) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.videocam_rounded, color: Colors.blue),
            const SizedBox(width: 10),
            const Expanded(child: Text('A video was attached by the parent.')),
            TextButton.icon(
              onPressed: () async {
                final opened = await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to open the video.')),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('View'),
            ),
          ],
        ),
      );
    }

    if (_isFile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_file_rounded, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName?.trim().isNotEmpty == true
                    ? fileName!
                    : 'A supporting file was attached by the parent.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final opened = await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to open the attachment.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('Open'),
            ),
          ],
        ),
      );
    }

    final isWideScreen = MediaQuery.sizeOf(context).width >= 700;
    final previewHeight = isWideScreen ? 220.0 : 180.0;

    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Unable to load the uploaded image.'),
                ),
              ),
            ),
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: previewHeight,
          width: double.infinity,
          color: Colors.black.withValues(alpha: .04),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              color: Colors.blue.withValues(alpha: .08),
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, color: Colors.blue),
                  SizedBox(height: 6),
                  Text('Unable to load the uploaded image.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingEvidenceNotice extends StatelessWidget {
  const _MissingEvidenceNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: Colors.red),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Required proof is missing. This submission cannot be graded.',
          ),
        ),
      ],
    ),
  );
}
