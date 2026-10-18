enum ConsentType {
  terms,
  privacyNotice,
  childDataProcessing,
}

extension ConsentTypeX on ConsentType {
  String get value {
    switch (this) {
      case ConsentType.terms:
        return 'terms';
      case ConsentType.privacyNotice:
        return 'privacy_notice';
      case ConsentType.childDataProcessing:
        return 'child_data_processing';
    }
  }

  static ConsentType fromValue(String? value) {
    for (final type in ConsentType.values) {
      if (type.value == value) return type;
    }
    return ConsentType.privacyNotice;
  }
}

class ConsentRecordModel {
  final String id;
  final String actorUid;
  final String? subjectUid;
  final String? childId;
  final ConsentType type;
  final String noticeVersion;
  final String legalBasis;
  final String purpose;
  final String acceptedAt;
  final String? withdrawnAt;
  final String? guardianRelationship;
  final String source;

  const ConsentRecordModel({
    required this.id,
    required this.actorUid,
    this.subjectUid,
    this.childId,
    required this.type,
    required this.noticeVersion,
    required this.legalBasis,
    required this.purpose,
    required this.acceptedAt,
    this.withdrawnAt,
    this.guardianRelationship,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'actor_uid': actorUid,
      'subject_uid': subjectUid,
      'child_id': childId,
      'type': type.value,
      'notice_version': noticeVersion,
      'legal_basis': legalBasis,
      'purpose': purpose,
      'accepted_at': acceptedAt,
      'withdrawn_at': withdrawnAt,
      'guardian_relationship': guardianRelationship,
      'source': source,
    };
  }

  factory ConsentRecordModel.fromMap(Map<String, dynamic> map) {
    return ConsentRecordModel(
      id: map['id'] as String? ?? '',
      actorUid: map['actor_uid'] as String? ?? '',
      subjectUid: map['subject_uid'] as String?,
      childId: map['child_id'] as String?,
      type: ConsentTypeX.fromValue(map['type'] as String?),
      noticeVersion: map['notice_version'] as String? ?? '',
      legalBasis: map['legal_basis'] as String? ?? '',
      purpose: map['purpose'] as String? ?? '',
      acceptedAt: map['accepted_at'] as String? ?? '',
      withdrawnAt: map['withdrawn_at'] as String?,
      guardianRelationship: map['guardian_relationship'] as String?,
      source: map['source'] as String? ?? 'unknown',
    );
  }
}
