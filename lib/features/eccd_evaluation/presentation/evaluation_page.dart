import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../data/evaluation_repository.dart';
import '../domain/evaluation_model.dart';
import 'evaluation_history_page.dart';

class EvaluationPage extends StatefulWidget {
  const EvaluationPage({super.key});

  @override
  State<EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<EvaluationPage> {
  final EvaluationRepository _repository = EvaluationRepositoryImpl();
  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
  bool _isLoading = true;

  final List<String> _domains = [
    'Physical',
    'Cognitive',
    'Language',
    'Social Emotional',
    'Self Help'
  ];

  String _selectedDomain = 'Physical';
  final _scoreController = TextEditingController();
  final _remarksController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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
      }
    });
  }

  void _saveEvaluation() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedChild == null) return;

      final evaluation = EvaluationModel(
        childId: _selectedChild!.childId,
        domain: _selectedDomain,
        score: int.parse(_scoreController.text),
        remarks: _remarksController.text,
        evaluationDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _repository.addEvaluation(evaluation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluation saved successfully!')),
        );
        _scoreController.clear();
        _remarksController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECCD Evaluation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              if (_selectedChild != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EvaluationHistoryPage(child: _selectedChild!),
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
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildChildInfo(),
                    const SizedBox(height: 32),
                    DropdownButtonFormField<ChildModel>(
                      initialValue: _selectedChild,
                      decoration: const InputDecoration(
                        labelText: 'Select Child',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: _children.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text('${c.firstName} ${c.lastName}'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedChild = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDomain,
                      decoration: const InputDecoration(
                        labelText: 'Development Domain',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _domains.map((d) {
                        return DropdownMenuItem(value: d, child: Text(d));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedDomain = val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _scoreController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Score',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.score),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (int.tryParse(value) == null) return 'Enter a number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.comment),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveEvaluation,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save Evaluation', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildChildInfo() {
    if (_selectedChild == null) return const SizedBox.shrink();
    return Card(
      color: Colors.blue.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Child Information',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
              ],
            ),
            const Divider(),
            _infoRow('Child ID:', _selectedChild!.childId),
            _infoRow('Age:', '${_selectedChild!.age} yrs old'),
            _infoRow('Gender:', _selectedChild!.gender),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
