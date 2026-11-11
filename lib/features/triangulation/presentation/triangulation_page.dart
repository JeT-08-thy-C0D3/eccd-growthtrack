import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/triangulation_repository_impl.dart';
import '../domain/triangulation_model.dart';
import 'triangulation_history_page.dart';

class TriangulationPage extends StatefulWidget {
  const TriangulationPage({super.key});

  @override
  State<TriangulationPage> createState() => _TriangulationPageState();
}

class _TriangulationPageState extends State<TriangulationPage> {
  final _repository = TriangulationRepositoryImpl();
  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
  String _selectedSectionFilter = 'All Sections';
  bool _isLoading = true;
  bool _isGenerating = false;

  Map<String, dynamic>? _inputs;
  String _status = 'On Track';
  final _triangulatedSummaryController = TextEditingController();

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
        _loadInputs();
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
      if (_selectedChild == null) _inputs = null;
    });
    if (_selectedChild != null) await _loadInputs();
  }

  Future<void> _loadInputs() async {
    if (_selectedChild == null) return;
    setState(() => _isLoading = true);
    final data = await _repository.fetchTriangulationInputs(
      _selectedChild!.childId,
    );
    setState(() {
      _inputs = data;
      _isLoading = false;
      _triangulatedSummaryController.text = _generateMockAnalysis();
    });
  }

  String _generateMockAnalysis() {
    if (_inputs == null) return '';
    return "Based on Teacher's assessment of ${_inputs!['teacher_summary']} and Parent's feedback of ${_inputs!['parent_summary']}, the child is showing consistent growth. ${_inputs!['history_summary']}";
  }

  void _saveTriangulation() async {
    if (_selectedChild == null || _inputs == null) return;

    setState(() => _isGenerating = true);

    final triangulation = TriangulationModel(
      childId: _selectedChild!.childId,
      teacherAssessmentSummary: _inputs!['teacher_summary'],
      parentFeedbackSummary: _inputs!['parent_summary'],
      historicalRecordSummary: _inputs!['history_summary'],
      triangulatedSummary: _triangulatedSummaryController.text,
      developmentStatus: _status,
      generatedDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      updatedAt: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    );

    await _repository.saveTriangulation(triangulation);

    setState(() => _isGenerating = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Triangulation Analysis Saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECCD Triangulation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              if (_selectedChild != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TriangulationHistoryPage(child: _selectedChild!),
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
                      labelText: 'Select Child for Analysis',
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
                      _loadInputs();
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildInputCard(
                    'Teacher Assessment',
                    _inputs?['teacher_summary'],
                    Icons.school,
                    Colors.blue,
                  ),
                  _buildInputCard(
                    'Parent Feedback',
                    _inputs?['parent_summary'],
                    Icons.family_restroom,
                    Colors.orange,
                  ),
                  _buildInputCard(
                    'Historical Record',
                    _inputs?['history_summary'],
                    Icons.history,
                    Colors.green,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Intelligent Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Development Status',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        ['On Track', 'Needs Monitoring', 'Needs Intervention']
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: (val) => setState(() => _status = val!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _triangulatedSummaryController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Triangulated Summary & Recommendations',
                      border: OutlineInputBorder(),
                      hintText: 'Synthesizing data from all sources...',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _saveTriangulation,
                    icon: const Icon(Icons.analytics),
                    label: const Text('Save Triangulation Analysis'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInputCard(
    String title,
    String? summary,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary ?? 'Loading...',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
