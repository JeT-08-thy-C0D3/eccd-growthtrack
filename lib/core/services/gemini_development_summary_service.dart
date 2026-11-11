import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import '../../features/triangulation/domain/triangulation_model.dart';

/// A teacher-reviewable development-summary draft produced from a completed
/// triangulation. This is intentionally not a chat feature.
class AiDevelopmentSummaryDraft {
  const AiDevelopmentSummaryDraft({
    required this.developmentSummary,
    required this.strengthAreas,
    required this.improvementAreas,
    required this.suggestedHomeActivities,
  });

  final String developmentSummary;
  final String strengthAreas;
  final String improvementAreas;
  final String suggestedHomeActivities;

  factory AiDevelopmentSummaryDraft.fromJson(Map<String, dynamic> json) {
    String value(String key) => (json[key] ?? '').toString().trim();

    return AiDevelopmentSummaryDraft(
      developmentSummary: value('developmentSummary'),
      strengthAreas: value('strengthAreas'),
      improvementAreas: value('improvementAreas'),
      suggestedHomeActivities: value('suggestedHomeActivities'),
    );
  }
}

class GeminiDevelopmentSummaryService {
  GeminiDevelopmentSummaryService({GenerativeModel? model})
    : _models = model == null
          ? _createCompatibleModels()
          : <GenerativeModel>[model];

  /// Model availability can differ during Firebase AI Logic rollouts. The
  /// report uses text and JSON, which all models below support. We only try a
  /// fallback when Firebase specifically says that a model is unavailable;
  /// auth, App Check, quota, and validation failures are never retried.
  static List<GenerativeModel> _createCompatibleModels() {
    final googleAi = FirebaseAI.googleAI(
      // Firebase AI does not implicitly attach App Check in the installed SDK
      // version. Supplying the shared instance makes each request include the
      // current X-Firebase-AppCheck token.
      appCheck: FirebaseAppCheck.instance,
    );
    return <GenerativeModel>[
      // This Firebase project has the Gemini Developer API enabled. Keep all
      // requests on that configured backend; Agent Platform/Vertex is not
      // enabled and should never be used as a fallback.
      googleAi.generativeModel(model: 'gemini-3.8-flash'),
      googleAi.generativeModel(model: 'gemini-2.5-flash'),
      googleAi.generativeModel(model: 'gemini-2.0-flash'),
      googleAi.generativeModel(model: 'gemini-3.5-flash-lite'),
    ];
  }

  final List<GenerativeModel> _models;
  int? _workingModelIndex;

  /// Produces a transparent teacher-review draft when Firebase AI Logic is
  /// temporarily unavailable. It deliberately reuses only the saved
  /// triangulation inputs; it does not present itself as an AI result or add
  /// any new child observations.
  AiDevelopmentSummaryDraft createDataBasedFallback({
    required String childFirstName,
    required TriangulationModel triangulation,
  }) {
    final status = triangulation.developmentStatus.trim().isEmpty
        ? 'being monitored'
        : triangulation.developmentStatus.trim().toLowerCase();
    final teacherAssessment = triangulation.teacherAssessmentSummary.trim();
    return AiDevelopmentSummaryDraft(
      developmentSummary:
          '$childFirstName is currently $status based on the teacher assessment, parent feedback, and development history recorded by the school. ${triangulation.triangulatedSummary.trim()}',
      strengthAreas: 'Teacher assessment: $teacherAssessment',
      improvementAreas:
          'Continue to monitor the areas identified in the current analysis: ${triangulation.historicalRecordSummary.trim()}',
      suggestedHomeActivities: _suggestedActivitiesFor(
        teacherAssessment,
        status,
      ),
    );
  }

  String _suggestedActivitiesFor(String assessment, String status) {
    final source = assessment.toLowerCase();
    final intensity = status.contains('intervention')
        ? 'Use short, guided daily practice and share observations with the teacher.'
        : status.contains('monitoring')
        ? 'Practice briefly each day and review progress with the teacher.'
        : 'Keep activities playful and gradually add a small challenge.';
    if (source.contains('gross motor')) {
      return 'Gross-motor play: set up a safe indoor obstacle course, practice hopping or balancing, and play follow-the-leader with movement actions. $intensity';
    }
    if (source.contains('fine motor')) {
      return 'Fine-motor play: draw lines and shapes, sort small safe objects with tongs, and build with blocks or clay. $intensity';
    }
    if (source.contains('language') || source.contains('communication')) {
      return 'Language play: read a short picture book, name objects in daily routines, and take turns telling a simple story. $intensity';
    }
    if (source.contains('social') || source.contains('emotional')) {
      return 'Social-emotional play: practice turn-taking games, name feelings in stories, and praise calm problem-solving. $intensity';
    }
    if (source.contains('cognitive')) {
      return 'Thinking play: sort by color or size, complete simple matching games, and ask the child to explain choices. $intensity';
    }
    return 'Choose short, enjoyable daily activities connected to the teacher\'s current goals, such as reading together, drawing or sorting objects, and practicing turn-taking. $intensity';
  }

  Future<AiDevelopmentSummaryDraft> generateDraft({
    required String childFirstName,
    required TriangulationModel triangulation,
  }) async {
    final prompt =
        '''
You are an ECCD development-report drafting assistant for a teacher.
Create a concise, strengths-based, teacher-reviewable draft for $childFirstName.

Important rules:
- Use only the supplied records; do not invent observations, scores, diagnoses, or risks.
- Use respectful, plain language for a parent audience.
- Do not use offensive, abusive, or profane language.
- This is a decision-support draft, not a diagnosis or a final report.
- If a detail is missing, write a careful, general recommendation instead of guessing.
- Give 3 to 5 practical, age-appropriate home activities.

Triangulation status: ${triangulation.developmentStatus}
Teacher assessment: ${triangulation.teacherAssessmentSummary}
Parent feedback: ${triangulation.parentFeedbackSummary}
Historical records: ${triangulation.historicalRecordSummary}
Teacher triangulated analysis: ${triangulation.triangulatedSummary}

Return only a JSON object using exactly these string fields:
{
  "developmentSummary": "",
  "strengthAreas": "",
  "improvementAreas": "",
  "suggestedHomeActivities": ""
}
''';

    Object? unavailableModelError;
    final modelIndexes = <int>[
      ?_workingModelIndex,
      for (var index = 0; index < _models.length; index++)
        if (index != _workingModelIndex) index,
    ];
    for (var position = 0; position < modelIndexes.length; position++) {
      final index = modelIndexes[position];
      try {
        final response = await _models[index].generateContent(
          [Content.text(prompt)],
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: Schema.object(
              properties: {
                'developmentSummary': Schema.string(),
                'strengthAreas': Schema.string(),
                'improvementAreas': Schema.string(),
                'suggestedHomeActivities': Schema.string(),
              },
            ),
          ),
        );
        _workingModelIndex = index;
        return _parseDraft(response.text);
      } catch (error) {
        final hasFallback = position < modelIndexes.length - 1;
        if (!hasFallback || !_isUnavailableModelError(error)) rethrow;
        unavailableModelError = error;
      }
    }

    // The loop either returns or rethrows. Keeping this guard makes the
    // control flow explicit should models be changed in the future.
    throw unavailableModelError ??
        StateError('No compatible Firebase AI model is configured.');
  }

  bool _isUnavailableModelError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('model') &&
        (message.contains('unavailable') ||
            message.contains('not found') ||
            message.contains('not supported'));
  }

  AiDevelopmentSummaryDraft _parseDraft(String? responseTextValue) {
    final responseText = responseTextValue?.trim();
    if (responseText == null || responseText.isEmpty) {
      throw StateError('Gemini returned an empty development-summary draft.');
    }

    final decoded = jsonDecode(responseText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Gemini returned an invalid draft format.');
    }

    final draft = AiDevelopmentSummaryDraft.fromJson(decoded);
    if (draft.developmentSummary.isEmpty) {
      throw const FormatException('Gemini returned an incomplete draft.');
    }
    return draft;
  }
}
