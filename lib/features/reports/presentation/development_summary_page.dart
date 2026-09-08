import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../triangulation/domain/triangulation_model.dart';
import '../data/development_summary_repository.dart';
import '../domain/development_summary_model.dart';
import 'development_summary_history_page.dart';

class DevelopmentSummaryPage extends StatefulWidget {
  const DevelopmentSummaryPage({super.key});

  @override
  State<DevelopmentSummaryPage> createState() => _DevelopmentSummaryPageState();
}

class _DevelopmentSummaryPageState extends State<DevelopmentSummaryPage> {
  final DevelopmentSummaryRepository _repository = DevelopmentSummaryRepositoryImpl();
  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
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
    final data = await DatabaseHelper.instance.getAllChildren();
    setState(() {
      _children = data;
      _isLoading = false;
      if (_children.isNotEmpty) {
        _selectedChild = _children.first;
        _loadLatestTriangulation();
      }
    });
  }

  Future<void> _loadLatestTriangulation() async {
    if (_selectedChild == null) return;
    setState(() => _isLoading = true);
    final history = await DatabaseHelper.instance.getTriangulationHistory(_selectedChild!.childId);
    setState(() {
      if (history.isNotEmpty) {
        _latestTriangulation = TriangulationModel.fromMap(history.first);
      } else {
        _latestTriangulation = null;
      }
      _isLoading = false;
    });
  }

  void _generateAISummary() async {
    if (_latestTriangulation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please generate a triangulation analysis first.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    
    // Simulate AI Latency
    await Future.delayed(const Duration(seconds: 2));

    // Mock AI Generation Logic based on Triangulation Status
    String status = _latestTriangulation!.developmentStatus;
    
    setState(() {
      _summaryController.text = "Based on the latest multi-source analysis, the child's development is categorized as '$status'. They show positive engagement in most classroom activities.";
      _strengthsController.text = "Social engagement with peers, following simple instructions, and physical coordination.";
      _improvementsController.text = status == 'On Track' ? "Continue fine motor practice." : "Focus on expressive language and vocabulary expansion.";
      _activitiesController.text = "1. Daily story reading sessions.\n2. Shape sorting games.\n3. Outdoor cooperative play.";
      _isGenerating = false;
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
    );

    await _repository.addSummary(summary);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Summary saved as $status!')),
      );
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
                    builder: (context) => DevelopmentSummaryHistoryPage(child: _selectedChild!),
                  ),
                );
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<ChildModel>(
                    initialValue: _selectedChild,
                    decoration: const InputDecoration(labelText: 'Select Child', border: OutlineInputBorder()),
                    items: _children.map((c) => DropdownMenuItem(value: c, child: Text("${c.firstName} ${c.lastName}"))).toList(),
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
                        child: Text('No triangulation found for this child. Please complete a Triangulation Analysis first.', style: TextStyle(color: Colors.white)),
                      ),
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Latest Triangulation Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(_latestTriangulation!.developmentStatus, style: const TextStyle(fontSize: 18, color: Colors.blue)),
                            const SizedBox(height: 8),
                            const Text('Generated Date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(_latestTriangulation!.generatedDate, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateAISummary,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(_isGenerating ? 'Analyzing with AI...' : 'Generate AI Summary'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSummaryField('Development Summary', _summaryController),
                    _buildSummaryField('Strength Areas', _strengthsController),
                    _buildSummaryField('Areas for Improvement', _improvementsController),
                    _buildSummaryField('Suggested Home Activities', _activitiesController, maxLines: 4),
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
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
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

  Widget _buildSummaryField(String label, TextEditingController controller, {int maxLines = 3}) {
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
