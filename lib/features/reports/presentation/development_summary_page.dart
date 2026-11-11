import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/gemini_development_summary_service.dart';
import '../../../shared/models/child_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../triangulation/domain/triangulation_model.dart';
import '../../triangulation/data/triangulation_repository_impl.dart';
import '../data/development_summary_repository.dart';
import '../domain/development_summary_model.dart';
import '../../notification/data/notification_repository.dart';
import 'development_summary_history_page.dart';

class DevelopmentSummaryPage extends StatefulWidget {
  const DevelopmentSummaryPage({super.key});

  @override
  State<DevelopmentSummaryPage> createState() => _DevelopmentSummaryPageState();
}

class _DevelopmentSummaryPageState extends State<DevelopmentSummaryPage> {
  final DevelopmentSummaryRepository _repository =
      DevelopmentSummaryRepositoryImpl();
  final TriangulationRepositoryImpl _triangulationRepository =
      TriangulationRepositoryImpl();
  final GeminiDevelopmentSummaryService _geminiService =
      GeminiDevelopmentSummaryService();
  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
  String _selectedSectionFilter = 'All Sections';
  TriangulationModel? _latestTriangulation;
  bool _isLoading = true;
  bool _isGenerating = false;

  final _summaryController = TextEditingController();
  final _strengthsController = TextEditingController();
  final _improvementsController = TextEditingController();
  final _activitiesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    final data = teacher == null
        ? <ChildModel>[]
        : teacher.role.name == 'teacher'
        ? await DatabaseHelper.instance.readChildrenByTeacher(teacher.uid)
        : await DatabaseHelper.instance.getAllChildren();
    if (!mounted) return;
    setState(() {
      _children = data;
      _isLoading = false;
      if (_children.isNotEmpty) {
        _selectedChild = _children.first;
        _loadLatestTriangulation();
      }
    });
  }

  List<ChildModel> get _sectionChildren =>
      _selectedSectionFilter == 'All Sections'
      ? _children
      : _children
            .where((child) => child.section.label == _selectedSectionFilter)
            .toList();

  Future<void> _onSectionChanged(String? section) async {
    final selectedSection = section ?? 'All Sections';
    final children = selectedSection == 'All Sections'
        ? _children
        : _children
              .where((child) => child.section.label == selectedSection)
              .toList();
    setState(() {
      _selectedSectionFilter = selectedSection;
      _selectedChild = children.contains(_selectedChild)
          ? _selectedChild
          : (children.isEmpty ? null : children.first);
      if (_selectedChild == null) _latestTriangulation = null;
    });
    if (_selectedChild != null) await _loadLatestTriangulation();
  }

  Future<void> _loadLatestTriangulation() async {
    if (_selectedChild == null) return;
    final childId = _selectedChild!.childId;
    setState(() => _isLoading = true);
    final history = await _triangulationRepository.getHistory(childId);
    final latest = history.isEmpty
        ? null
        : await _withCurrentSourceData(history.first);
    if (!mounted || _selectedChild?.childId != childId) return;
    setState(() {
      _latestTriangulation = latest;
      _isLoading = false;
    });
  }

  /// A saved triangulation preserves the teacher's conclusion and status, but
  /// its source summaries can become stale after new assessments or parent
  /// feedback arrive. Refresh those source summaries before displaying or
  /// sending them to AI, without overwriting the saved analysis in Firestore.
  Future<TriangulationModel> _withCurrentSourceData(
    TriangulationModel saved,
  ) async {
    final inputs = await _triangulationRepository.fetchTriangulationInputs(
      saved.childId,
    );
    final evaluations = inputs['evaluations'];
    final feedback = inputs['feedback'];
    final history = inputs['history'];
    final hasEvaluations = evaluations is List && evaluations.isNotEmpty;
    final hasFeedback = feedback is List && feedback.isNotEmpty;
    final hasHistory = history is List && history.isNotEmpty;
    return saved.copyWith(
      teacherAssessmentSummary: hasEvaluations
          ? inputs['teacher_summary']?.toString()
          : saved.teacherAssessmentSummary,
      parentFeedbackSummary: hasFeedback
          ? inputs['parent_summary']?.toString()
          : saved.parentFeedbackSummary,
      historicalRecordSummary: hasHistory
          ? inputs['history_summary']?.toString()
          : saved.historicalRecordSummary,
    );
  }

  Future<void> _generateAISummary() async {
    if (_latestTriangulation == null || _selectedChild == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate a triangulation analysis first.'),
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // _loadLatestTriangulation already selects the most recent saved
      // triangulation and refreshes its supporting source summaries. Reusing
      // it here avoids a second full Firestore read before every AI request.
      final currentTriangulation = _latestTriangulation!;
      final draft = await _geminiService.generateDraft(
        childFirstName: _selectedChild!.firstName,
        triangulation: currentTriangulation,
      );
      if (!mounted) return;
      _applyDraft(draft);
    } catch (error, stackTrace) {
      debugPrint('Firebase AI development-summary request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      // Firebase AI Logic needs a Firebase Console setup and can be
      // temporarily unavailable. Keep the teacher workflow usable by filling
      // a clearly data-based, editable draft from the saved triangulation.
      final fallback = _geminiService.createDataBasedFallback(
        childFirstName: _selectedChild!.firstName,
        triangulation: _latestTriangulation!,
      );
      if (!mounted) return;
      _applyDraft(fallback);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_aiFailureMessage(error)} A data-based draft was prepared for teacher review.',
          ),
          duration: const Duration(seconds: 12),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  String _aiFailureMessage(Object error) {
    final message = error.toString();
    final normalized = message.toLowerCase();
    if (normalized.contains('app check') ||
        normalized.contains('appcheck') ||
        normalized.contains('recaptcha')) {
      return 'App Check token was rejected. Verify the Enterprise site key and restart the web app with the dart-define command.';
    }
    if (normalized.contains('permission') ||
        normalized.contains('api has not been used') ||
        normalized.contains('not enabled')) {
      return 'Firebase AI Logic or Gemini Developer API is not enabled for this project.';
    }
    if (normalized.contains('model') || normalized.contains('not found')) {
      return 'The configured Gemini model is unavailable for this Firebase project.';
    }
    return 'Request failed: ${message.length > 180 ? '${message.substring(0, 180)}…' : message}';
  }

  void _applyDraft(AiDevelopmentSummaryDraft draft) {
    setState(() {
      _summaryController.text = draft.developmentSummary;
      _strengthsController.text = draft.strengthAreas;
      _improvementsController.text = draft.improvementAreas;
      _activitiesController.text = draft.suggestedHomeActivities;
    });
  }

  void _saveSummary(String status) async {
    if (_selectedChild == null || _latestTriangulation == null) return;
    if (_summaryController.text.isEmpty) return;

    final user = await AuthRepositoryImpl().getCurrentUser();
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final summary = DevelopmentSummaryModel(
      childId: _selectedChild!.childId,
      triangulationId: _latestTriangulation!.id!,
      developmentSummary: _summaryController.text,
      strengthAreas: _strengthsController.text,
      improvementAreas: _improvementsController.text,
      suggestedHomeActivities: _activitiesController.text,
      approvalStatus: status,
      approvedBy: status == 'Approved' ? user?.name : null,
      approvedDate: status == 'Approved' ? now : null,
      createdDate: now,
      updatedAt: now,
    );

    await _repository.addSummary(summary);

    if (status == 'Approved') {
      await NotificationRepositoryImpl().sendNotification(
        childId: _selectedChild!.childId,
        type: 'development_summary',
        title: 'Development Summary Approved',
        body:
            'The development summary for ${_selectedChild!.firstName} ${_selectedChild!.lastName} has been published by Teacher ${user?.name ?? ''}.',
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Summary saved as $status!')));
      if (status == 'Approved') Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-Assisted Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              if (_selectedChild != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DevelopmentSummaryHistoryPage(child: _selectedChild!),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSectionFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Section',
                      prefixIcon: Icon(Icons.groups_rounded),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'All Sections',
                        child: Text('All sections'),
                      ),
                      ...ChildSection.values.map(
                        (section) => DropdownMenuItem(
                          value: section.label,
                          child: Text(
                            '${section.label} (${section.ageRange})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: _onSectionChanged,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<ChildModel>(
                    initialValue: _selectedChild,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Child',
                      border: OutlineInputBorder(),
                    ),
                    items: _sectionChildren
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              "${c.firstName} ${c.lastName}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedChild = val);
                      _loadLatestTriangulation();
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_latestTriangulation == null)
                    const Card(
                      color: Colors.orangeAccent,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No triangulation found for this child. Please complete a Triangulation Analysis first.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Latest Triangulation Status:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _latestTriangulation!.developmentStatus,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Generated Date:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _latestTriangulation!.generatedDate,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _AiDecisionSupportNotice(),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateAISummary,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(
                        _isGenerating
                            ? 'Creating draft...'
                            : 'Generate AI-Assisted Draft',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSummaryField(
                      'Development Summary',
                      _summaryController,
                    ),
                    _buildSummaryField('Strength Areas', _strengthsController),
                    _buildSummaryField(
                      'Areas for Improvement',
                      _improvementsController,
                    ),
                    _buildSummaryField(
                      'Suggested Home Activities',
                      _activitiesController,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _saveSummary('Pending'),
                            child: const Text('Save as Draft'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _saveSummary('Approved'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Approve & Publish'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryField(
    String label,
    TextEditingController controller, {
    int maxLines = 3,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}

class _AiDecisionSupportNotice extends StatelessWidget {
  const _AiDecisionSupportNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF3ECFF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF7B1FA2).withValues(alpha: .2)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.auto_awesome_outlined, color: Color(0xFF7B1FA2)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'This creates a draft from assessments, teacher observations, parent feedback, and development history. Review, edit, and validate it before approving it for parents. It supports—never replaces—your professional judgment.',
            style: TextStyle(height: 1.35),
          ),
        ),
      ],
    ),
  );
}
