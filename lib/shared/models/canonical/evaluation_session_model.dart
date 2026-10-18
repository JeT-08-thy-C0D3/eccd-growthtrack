/// Canonical EvaluationSession model.
/// 
/// An EvaluationSession represents a complete evaluation of a child's
/// development across one or more domains during a specific session.
/// This consolidates the old AssessmentModel and any EvaluationModel.

class EvaluationSession {
  final String id; // Unique session ID (UUID)
  final String childId; // Reference to Child
  final String centerId; // Reference to Center where evaluation occurred
  final String evaluatorId; // Reference to User (teacher/evaluator)
  final DateTime sessionDate; // When the evaluation occurred
  final String ageBand; // Age band at time of evaluation (e.g., '24-30m')
  final List<EvaluationObservation> observations; // Individual observations
  final String status; // 'draft', 'submitted', 'verified', 'approved'
  final bool humanVerified; // Whether human has verified automated results
  final String? verifierUserId; // User who verified this session
  final DateTime? verifiedAt;
  final String checklistVersion; // Version of the ECCD checklist used
  final String? remarks; // Session-level notes
  final String? reviewNotes; // Notes from human verification
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced; // Sync status flag
  final String? syncedToFirestore; // Timestamp of last Firestore sync

  EvaluationSession({
    required this.id,
    required this.childId,
    required this.centerId,
    required this.evaluatorId,
    required this.sessionDate,
    required this.ageBand,
    required this.observations,
    required this.status,
    required this.humanVerified,
    required this.checklistVersion,
    this.verifierUserId,
    this.verifiedAt,
    this.remarks,
    this.reviewNotes,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.syncedToFirestore,
  });

  factory EvaluationSession.fromMap(Map<String, dynamic> map) {
    return EvaluationSession(
      id: map['id'] ?? '',
      childId: map['child_id'] ?? '',
      centerId: map['center_id'] ?? '',
      evaluatorId: map['evaluator_id'] ?? '',
      sessionDate: DateTime.parse(map['session_date'] ?? DateTime.now().toIso8601String()),
      ageBand: map['age_band'] ?? '',
      observations: (map['observations'] as List<dynamic>? ?? [])
          .map((o) => EvaluationObservation.fromMap(o as Map<String, dynamic>))
          .toList(),
      status: map['status'] ?? 'draft',
      humanVerified: (map['human_verified'] ?? 0) == 1,
      checklistVersion: map['checklist_version'] ?? '1.0',
      verifierUserId: map['verifier_user_id'] as String?,
      verifiedAt: map['verified_at'] != null 
          ? DateTime.parse(map['verified_at'] as String)
          : null,
      remarks: map['remarks'] as String?,
      reviewNotes: map['review_notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
      isSynced: (map['is_synced'] ?? 0) == 1,
      syncedToFirestore: map['synced_to_firestore'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'center_id': centerId,
      'evaluator_id': evaluatorId,
      'session_date': sessionDate.toIso8601String(),
      'age_band': ageBand,
      'observations': observations.map((o) => o.toMap()).toList(),
      'status': status,
      'human_verified': humanVerified ? 1 : 0,
      'checklist_version': checklistVersion,
      'verifier_user_id': verifierUserId,
      'verified_at': verifiedAt?.toIso8601String(),
      'remarks': remarks,
      'review_notes': reviewNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'synced_to_firestore': syncedToFirestore,
    };
  }

  EvaluationSession copyWith({
    String? id,
    String? childId,
    String? centerId,
    String? evaluatorId,
    DateTime? sessionDate,
    String? ageBand,
    List<EvaluationObservation>? observations,
    String? status,
    bool? humanVerified,
    String? checklistVersion,
    String? verifierUserId,
    DateTime? verifiedAt,
    String? remarks,
    String? reviewNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? syncedToFirestore,
  }) {
    return EvaluationSession(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      centerId: centerId ?? this.centerId,
      evaluatorId: evaluatorId ?? this.evaluatorId,
      sessionDate: sessionDate ?? this.sessionDate,
      ageBand: ageBand ?? this.ageBand,
      observations: observations ?? this.observations,
      status: status ?? this.status,
      humanVerified: humanVerified ?? this.humanVerified,
      checklistVersion: checklistVersion ?? this.checklistVersion,
      verifierUserId: verifierUserId ?? this.verifierUserId,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      remarks: remarks ?? this.remarks,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      syncedToFirestore: syncedToFirestore ?? this.syncedToFirestore,
    );
  }

  @override
  String toString() =>
      'EvaluationSession(childId=$childId, ${observations.length} observations, status=$status)';
}

/// EvaluationObservation represents a single observation within an
/// EvaluationSession. Each observation scores one indicator in one domain.
class EvaluationObservation {
  final String id; // Unique observation ID
  final String evaluationSessionId; // Parent session
  final String domainId; // ECCD domain (from EccdDomain)
  final String indicatorId; // Indicator within domain (from EccdIndicator)
  final int score; // Numeric score (e.g., 0-3)
  final String? evidenceSource; // How was this determined? ('observation', 'report', 'test', 'automated', etc.)
  final String? evidenceDescription; // Description of evidence
  final bool isAutomated; // True if score came from automated activity
  final String? automatedActivityId; // Reference to AutomatedActivityAttempt if applicable
  final double? automatedConfidence; // Confidence score if automated (0.0-1.0)
  final String? teacherNotes; // Teacher's comments on this observation
  final DateTime? verifiedAt; // When human verified this
  final bool teacherConfirmed; // Teacher confirmed automated result
  final DateTime createdAt;
  final DateTime updatedAt;

  EvaluationObservation({
    required this.id,
    required this.evaluationSessionId,
    required this.domainId,
    required this.indicatorId,
    required this.score,
    this.evidenceSource,
    this.evidenceDescription,
    this.isAutomated = false,
    this.automatedActivityId,
    this.automatedConfidence,
    this.teacherNotes,
    this.verifiedAt,
    this.teacherConfirmed = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EvaluationObservation.fromMap(Map<String, dynamic> map) {
    return EvaluationObservation(
      id: map['id'] ?? '',
      evaluationSessionId: map['evaluation_session_id'] ?? '',
      domainId: map['domain_id'] ?? '',
      indicatorId: map['indicator_id'] ?? '',
      score: map['score'] ?? 0,
      evidenceSource: map['evidence_source'] as String?,
      evidenceDescription: map['evidence_description'] as String?,
      isAutomated: (map['is_automated'] ?? 0) == 1,
      automatedActivityId: map['automated_activity_id'] as String?,
      automatedConfidence: (map['automated_confidence'] as num?)?.toDouble(),
      teacherNotes: map['teacher_notes'] as String?,
      verifiedAt: map['verified_at'] != null
          ? DateTime.parse(map['verified_at'] as String)
          : null,
      teacherConfirmed: (map['teacher_confirmed'] ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'evaluation_session_id': evaluationSessionId,
      'domain_id': domainId,
      'indicator_id': indicatorId,
      'score': score,
      'evidence_source': evidenceSource,
      'evidence_description': evidenceDescription,
      'is_automated': isAutomated ? 1 : 0,
      'automated_activity_id': automatedActivityId,
      'automated_confidence': automatedConfidence,
      'teacher_notes': teacherNotes,
      'verified_at': verifiedAt?.toIso8601String(),
      'teacher_confirmed': teacherConfirmed ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EvaluationObservation copyWith({
    String? id,
    String? evaluationSessionId,
    String? domainId,
    String? indicatorId,
    int? score,
    String? evidenceSource,
    String? evidenceDescription,
    bool? isAutomated,
    String? automatedActivityId,
    double? automatedConfidence,
    String? teacherNotes,
    DateTime? verifiedAt,
    bool? teacherConfirmed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EvaluationObservation(
      id: id ?? this.id,
      evaluationSessionId: evaluationSessionId ?? this.evaluationSessionId,
      domainId: domainId ?? this.domainId,
      indicatorId: indicatorId ?? this.indicatorId,
      score: score ?? this.score,
      evidenceSource: evidenceSource ?? this.evidenceSource,
      evidenceDescription: evidenceDescription ?? this.evidenceDescription,
      isAutomated: isAutomated ?? this.isAutomated,
      automatedActivityId: automatedActivityId ?? this.automatedActivityId,
      automatedConfidence: automatedConfidence ?? this.automatedConfidence,
      teacherNotes: teacherNotes ?? this.teacherNotes,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      teacherConfirmed: teacherConfirmed ?? this.teacherConfirmed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'EvaluationObservation(domain=$domainId, indicator=$indicatorId, score=$score)';
}
