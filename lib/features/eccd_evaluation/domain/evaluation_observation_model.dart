import 'eccd_domain.dart';

enum EvaluationObservationSource {
  teacher,
  parent,
  automated,
}

extension EvaluationObservationSourceX on EvaluationObservationSource {
  String get value {
    switch (this) {
      case EvaluationObservationSource.teacher:
        return 'teacher';
      case EvaluationObservationSource.parent:
        return 'parent';
      case EvaluationObservationSource.automated:
        return 'automated';
    }
  }

  static EvaluationObservationSource fromValue(String? value) {
    for (final source in EvaluationObservationSource.values) {
      if (source.value == value) return source;
    }
    return EvaluationObservationSource.teacher;
  }
}

class EvaluationObservationModel {
  final String id;
  final String sessionId;
  final String childId;
  final EccdDomain domain;
  final String indicatorId;
  final int score;
  final int maxScore;
  final EvaluationObservationSource source;
  final String? evaluatorUid;
  final String observedAt;
  final String? remarks;
  final String? evidenceRef;
  final String checklistVersion;
  final bool humanVerified;

  const EvaluationObservationModel({
    required this.id,
    required this.sessionId,
    required this.childId,
    required this.domain,
    required this.indicatorId,
    required this.score,
    required this.maxScore,
    required this.source,
    this.evaluatorUid,
    required this.observedAt,
    this.remarks,
    this.evidenceRef,
    required this.checklistVersion,
    this.humanVerified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'child_id': childId,
      'domain': domain.code,
      'indicator_id': indicatorId,
      'score': score,
      'max_score': maxScore,
      'source': source.value,
      'evaluator_uid': evaluatorUid,
      'observed_at': observedAt,
      'remarks': remarks,
      'evidence_ref': evidenceRef,
      'checklist_version': checklistVersion,
      'human_verified': humanVerified,
    };
  }

  factory EvaluationObservationModel.fromMap(Map<String, dynamic> map) {
    final domain = EccdDomainCatalog.tryParse(map['domain'] as String?);
    if (domain == null) {
      throw FormatException('Unknown ECCD domain: ${map['domain']}');
    }

    return EvaluationObservationModel(
      id: map['id'] as String? ?? '',
      sessionId: map['session_id'] as String? ?? '',
      childId: map['child_id'] as String? ?? '',
      domain: domain,
      indicatorId: map['indicator_id'] as String? ?? '',
      score: (map['score'] as num?)?.toInt() ?? 0,
      maxScore: (map['max_score'] as num?)?.toInt() ?? 0,
      source: EvaluationObservationSourceX.fromValue(map['source'] as String?),
      evaluatorUid: map['evaluator_uid'] as String?,
      observedAt: map['observed_at'] as String? ?? '',
      remarks: map['remarks'] as String?,
      evidenceRef: map['evidence_ref'] as String?,
      checklistVersion: map['checklist_version'] as String? ?? '',
      humanVerified: map['human_verified'] as bool? ?? false,
    );
  }
}
