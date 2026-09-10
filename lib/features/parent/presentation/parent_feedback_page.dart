import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/parent_feedback_repository.dart';
import '../domain/parent_feedback_model.dart';

class ParentFeedbackPage extends StatefulWidget {
  final ParentFeedbackModel? feedback; // If provided, we are in Edit mode
  const ParentFeedbackPage({super.key, this.feedback});

  @override
  State<ParentFeedbackPage> createState() => _ParentFeedbackPageState();
}

class _ParentFeedbackPageState extends State<ParentFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ParentFeedbackRepositoryImpl();
  
  ChildModel? _selectedChild;
  List<ChildModel> _children = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final _observationController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedAssistance = 'Independent';

  final List<String> _assistanceLevels = [
    'Independent',
    'Minimal Assistance',
    'Moderate Assistance',
    'Full Assistance',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.feedback != null) {
      _observationController.text = widget.feedback!.parentObservation;
      _notesController.text = widget.feedback!.notes;
      _selectedAssistance = widget.feedback!.assistanceLevel;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AuthRepositoryImpl().getCurrentUser();
    if (user != null) {
      final children = await DatabaseHelper.instance.readChildrenByParent(user.id!);
      setState(() {
        _children = children;
        if (widget.feedback != null) {
          _selectedChild = children.firstWhere((c) => c.childId == widget.feedback!.childId);
        } else if (_children.isNotEmpty) {
          _selectedChild = _children.first;
        }
        _isLoading = false;
      });
    }
  }

  void _saveFeedback() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedChild == null) return;

      setState(() => _isSaving = true);
      
      final user = await AuthRepositoryImpl().getCurrentUser();
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final feedback = ParentFeedbackModel(
        id: widget.feedback?.id,
        childId: _selectedChild!.childId,
        parentId: user!.id!,
        parentObservation: _observationController.text,
        assistanceLevel: _selectedAssistance,
        notes: _notesController.text,
        submissionDate: widget.feedback?.submissionDate ?? now,
      );

      if (widget.feedback != null) {
        await _repository.updateFeedback(feedback);
      } else {
        await _repository.submitFeedback(feedback);
      }

      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.feedback != null ? 'Feedback updated!' : 'Feedback submitted!')),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.feedback != null ? 'Edit Feedback' : 'Parent Feedback')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<ChildModel>(
                      initialValue: _selectedChild,
                      decoration: const InputDecoration(
                        labelText: 'Select Child',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.child_care),
                      ),
                      items: _children.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text("${c.firstName} ${c.lastName}"),
                      )).toList(),
                      onChanged: widget.feedback != null ? null : (val) => setState(() => _selectedChild = val),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _observationController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Your Observation',
                        border: OutlineInputBorder(),
                        hintText: 'What did you observe about your child today?',
                        prefixIcon: Icon(Icons.visibility),
                      ),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAssistance,
                      decoration: const InputDecoration(
                        labelText: 'Assistance Level',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.help_outline),
                      ),
                      items: _assistanceLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (val) => setState(() => _selectedAssistance = val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes',
                        border: OutlineInputBorder(),
                        hintText: 'Any other details you want to share?',
                        prefixIcon: Icon(Icons.note),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveFeedback,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(widget.feedback != null ? 'Update Feedback' : 'Submit Feedback', style: const TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
