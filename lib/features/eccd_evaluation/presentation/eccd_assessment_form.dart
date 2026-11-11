import 'package:flutter/material.dart';

import '../../../shared/models/child_model.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../data/evaluation_repository.dart';
import '../domain/evaluation_model.dart';

class EccdAssessmentForm extends StatefulWidget {
  final ChildModel child;
  const EccdAssessmentForm({super.key, required this.child});

  @override
  State<EccdAssessmentForm> createState() => _EccdAssessmentFormState();
}

class _EccdAssessmentFormState extends State<EccdAssessmentForm> {
  final EvaluationRepository _evaluationRepository = EvaluationRepositoryImpl();
  final Map<String, List<String>> _domains = {
    'Gross Motor': [
      'Climbs stairs with alternating feet',
      'Runs without falling',
      'Kicks a ball',
      'Stands on one foot for 5 seconds',
    ],
    'Fine Motor': [
      'Uses spoon and fork',
      'Copies a circle',
      'Strings large beads',
      'Turns pages of a book one at a time',
    ],
    'Self-Help': [
      'Feeds self independently',
      'Tells when they need to go to the toilet',
      'Washes hands without help',
      'Dresses self with minimal help',
    ],
    'Language': [
      'Points to body parts',
      'Uses 2-3 word sentences',
      'Follows simple commands',
      'Identifies common objects in pictures',
    ],
    'Cognitive': [
      'Identifies colors',
      'Matches shapes',
      'Counts 1 to 5',
      'Knows their name and age',
    ],
    'Social-Emotional': [
      'Plays with other children',
      'Shares toys',
      'Expresses emotions',
      'Shows empathy',
    ],
  };

  final Map<String, Map<int, bool>> _responses = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (var domain in _domains.keys) {
      _responses[domain] = {};
      for (int i = 0; i < _domains[domain]!.length; i++) {
        _responses[domain]![i] = false;
      }
    }
  }

  Future<void> _saveAssessment() async {
    int totalChecked = 0;
    _responses.forEach((domain, map) {
      map.forEach((index, isChecked) {
        if (isChecked) totalChecked++;
      });
    });

    if (totalChecked == 0) {
      final confirmSave = await ConfirmationDialog.show(
        context: context,
        title: 'Zero Items Selected',
        message:
            'No developmental indicators were selected for ${widget.child.firstName}. Do you still wish to submit an evaluation with 0 scores?',
        confirmLabel: 'Submit Anyway',
        confirmColor: Colors.orange,
        icon: Icons.warning_amber_rounded,
      );
      if (!confirmSave) return;
    }

    setState(() => _isSaving = true);
    final dateStr = DateTime.now().toIso8601String().split('T')[0];

    try {
      for (var domain in _domains.keys) {
        int score = 0;
        _responses[domain]!.forEach((key, value) {
          if (value) score++;
        });

        final assessment = EvaluationModel(
          childId: widget.child.childId,
          domain: domain,
          score: score,
          remarks: 'Assessment completed for $domain ($score/4)',
          evaluationDate: dateStr,
          updatedAt: DateTime.now().toIso8601String(),
        );

        // Reuse the active evaluation repository so all six checklist
        // domains follow the same local-first and Firestore-sync path as the
        // teacher evaluation screen, including on Flutter Web.
        await _evaluationRepository.addEvaluation(assessment);
      }

      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assessment saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save assessment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Evaluation: ${widget.child.firstName} ${widget.child.lastName}',
        ),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Developmental Checklist',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Check the items the child can perform.'),
                const Divider(),
                ..._domains.keys.map((domain) {
                  return ExpansionTile(
                    title: Text(
                      domain,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: [
                      ...List.generate(_domains[domain]!.length, (index) {
                        return CheckboxListTile(
                          title: Text(_domains[domain]![index]),
                          value: _responses[domain]![index],
                          onChanged: (val) {
                            setState(() {
                              _responses[domain]![index] = val!;
                            });
                          },
                        );
                      }),
                    ],
                  );
                }),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveAssessment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Submit Evaluation',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}
