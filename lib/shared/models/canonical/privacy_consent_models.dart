/// Privacy and Consent Framework
/// 
/// Implements GDPR/CCPA compliance including:
/// - Privacy notices (versioned)
/// - Consent records (audit trail)
/// - Data access requests
/// - Data deletion requests
/// - Relationship management

class PrivacyNotice {
  final String version; // e.g., '1.0', '2.0'
  final String title;
  final String content;
  final List<String> purposes; // e.g., ['evaluation', 'reporting', 'parent_feedback']
  final List<String> legalBases; // 'consent', 'legitimate_interest', 'contract'
  final String? dpoCo ntact; // Data Protection Officer email
  final DateTime effectiveDate;
  final DateTime? deprecatedDate; // When this version was superseded

  PrivacyNotice({
    required this.version,
    required this.title,
    required this.content,
    required this.purposes,
    required this.legalBases,
    this.dpoContact,
    required this.effectiveDate,
    this.deprecatedDate,
  });

  factory PrivacyNotice.fromMap(Map<String, dynamic> map) => PrivacyNotice(
    version: map['version'] ?? '',
    title: map['title'] ?? '',
    content: map['content'] ?? '',
    purposes: List<String>.from(map['purposes'] ?? []),
    legalBases: List<String>.from(map['legal_bases'] ?? []),
    dpoContact: map['dpo_contact'],
    effectiveDate: DateTime.parse(map['effective_date'] ?? DateTime.now().toIso8601String()),
    deprecatedDate: map['deprecated_date'] != null
        ? DateTime.parse(map['deprecated_date'])
        : null,
  );

  Map<String, dynamic> toMap() => {
    'version': version,
    'title': title,
    'content': content,
    'purposes': purposes,
    'legal_bases': legalBases,
    'dpo_contact': dpoContact,
    'effective_date': effectiveDate.toIso8601String(),
    'deprecated_date': deprecatedDate?.toIso8601String(),
  };

  bool get isActive => deprecatedDate == null;
}

class TermsOfUse {
  final String version;
  final String content;
  final DateTime effectiveDate;
  final DateTime? deprecatedDate;

  TermsOfUse({
    required this.version,
    required this.content,
    required this.effectiveDate,
    this.deprecatedDate,
  });

  factory TermsOfUse.fromMap(Map<String, dynamic> map) => TermsOfUse(
    version: map['version'] ?? '',
    content: map['content'] ?? '',
    effectiveDate: DateTime.parse(map['effective_date'] ?? DateTime.now().toIso8601String()),
    deprecatedDate: map['deprecated_date'] != null
        ? DateTime.parse(map['deprecated_date'])
        : null,
  );

  Map<String, dynamic> toMap() => {
    'version': version,
    'content': content,
    'effective_date': effectiveDate.toIso8601String(),
    'deprecated_date': deprecatedDate?.toIso8601String(),
  };

  bool get isActive => deprecatedDate == null;
}

/// Represents a parent-child relationship with documented relationship type
class ParentChildRelationship {
  final String id;
  final String parentId; // User UID
  final String childId;
  final String relationshipType; // 'parent', 'guardian', 'custodian', 'relative'
  final bool isPrimary; // Is this the primary contact?
  final bool hasLegalCustody; // Important for consent authority
  final DateTime createdAt;
  final DateTime? verifiedAt; // When relationship was verified

  ParentChildRelationship({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.relationshipType,
    this.isPrimary = false,
    this.hasLegalCustody = true,
    required this.createdAt,
    this.verifiedAt,
  });

  factory ParentChildRelationship.fromMap(Map<String, dynamic> map) =>
      ParentChildRelationship(
        id: map['id'] ?? '',
        parentId: map['parent_id'] ?? '',
        childId: map['child_id'] ?? '',
        relationshipType: map['relationship_type'] ?? 'parent',
        isPrimary: (map['is_primary'] ?? 0) == 1,
        hasLegalCustody: (map['has_legal_custody'] ?? 1) == 1,
        createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String()),
        verifiedAt: map['verified_at'] != null
            ? DateTime.parse(map['verified_at'])
            : null,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'parent_id': parentId,
    'child_id': childId,
    'relationship_type': relationshipType,
    'is_primary': isPrimary ? 1 : 0,
    'has_legal_custody': hasLegalCustody ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'verified_at': verifiedAt?.toIso8601String(),
  };
}

/// Request for user data export (right to access)
class DataAccessRequest {
  final String id;
  final String userId; // Who requested
  final String? dataSubjectId; // Whose data (may differ if parent requesting child data)
  final String status; // 'pending', 'processing', 'completed', 'denied'
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? exportFormat; // 'csv', 'json', 'pdf'
  final String? fileUrl; // Signed URL to download
  final String? denialReason; // If denied
  final DateTime? expiresAt; // When export link expires

  DataAccessRequest({
    required this.id,
    required this.userId,
    this.dataSubjectId,
    this.status = 'pending',
    required this.requestedAt,
    this.completedAt,
    this.exportFormat,
    this.fileUrl,
    this.denialReason,
    this.expiresAt,
  });

  factory DataAccessRequest.fromMap(Map<String, dynamic> map) =>
      DataAccessRequest(
        id: map['id'] ?? '',
        userId: map['user_id'] ?? '',
        dataSubjectId: map['data_subject_id'],
        status: map['status'] ?? 'pending',
        requestedAt: DateTime.parse(
            map['requested_at'] ?? DateTime.now().toIso8601String()),
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'])
            : null,
        exportFormat: map['export_format'],
        fileUrl: map['file_url'],
        denialReason: map['denial_reason'],
        expiresAt: map['expires_at'] != null
            ? DateTime.parse(map['expires_at'])
            : null,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'data_subject_id': dataSubjectId,
    'status': status,
    'requested_at': requestedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'export_format': exportFormat,
    'file_url': fileUrl,
    'denial_reason': denialReason,
    'expires_at': expiresAt?.toIso8601String(),
  };
}

/// Request to correct/update personal data
class DataCorrectionRequest {
  final String id;
  final String userId;
  final String dataSubjectId;
  final String fieldName; // Which field to correct
  final String currentValue;
  final String requestedValue;
  final String status; // 'pending', 'approved', 'rejected'
  final String? reason; // Why correction is needed
  final DateTime requestedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy; // Admin who approved/rejected

  DataCorrectionRequest({
    required this.id,
    required this.userId,
    required this.dataSubjectId,
    required this.fieldName,
    required this.currentValue,
    required this.requestedValue,
    this.status = 'pending',
    this.reason,
    required this.requestedAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  factory DataCorrectionRequest.fromMap(Map<String, dynamic> map) =>
      DataCorrectionRequest(
        id: map['id'] ?? '',
        userId: map['user_id'] ?? '',
        dataSubjectId: map['data_subject_id'] ?? '',
        fieldName: map['field_name'] ?? '',
        currentValue: map['current_value'] ?? '',
        requestedValue: map['requested_value'] ?? '',
        status: map['status'] ?? 'pending',
        reason: map['reason'],
        requestedAt: DateTime.parse(
            map['requested_at'] ?? DateTime.now().toIso8601String()),
        resolvedAt: map['resolved_at'] != null
            ? DateTime.parse(map['resolved_at'])
            : null,
        resolvedBy: map['resolved_by'],
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'data_subject_id': dataSubjectId,
    'field_name': fieldName,
    'current_value': currentValue,
    'requested_value': requestedValue,
    'status': status,
    'reason': reason,
    'requested_at': requestedAt.toIso8601String(),
    'resolved_at': resolvedAt?.toIso8601String(),
    'resolved_by': resolvedBy,
  };
}

/// Request to delete personal data (right to be forgotten)
class DataDeletionRequest {
  final String id;
  final String userId;
  final String dataSubjectId;
  final String? reason;
  final String status; // 'pending', 'approved', 'rejected', 'completed'
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? approvedBy;
  final String? notes;

  DataDeletionRequest({
    required this.id,
    required this.userId,
    required this.dataSubjectId,
    this.reason,
    this.status = 'pending',
    required this.requestedAt,
    this.completedAt,
    this.approvedBy,
    this.notes,
  });

  factory DataDeletionRequest.fromMap(Map<String, dynamic> map) =>
      DataDeletionRequest(
        id: map['id'] ?? '',
        userId: map['user_id'] ?? '',
        dataSubjectId: map['data_subject_id'] ?? '',
        reason: map['reason'],
        status: map['status'] ?? 'pending',
        requestedAt: DateTime.parse(
            map['requested_at'] ?? DateTime.now().toIso8601String()),
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'])
            : null,
        approvedBy: map['approved_by'],
        notes: map['notes'],
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'data_subject_id': dataSubjectId,
    'reason': reason,
    'status': status,
    'requested_at': requestedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'approved_by': approvedBy,
    'notes': notes,
  };
}

/// Record of data retention and disposal
class RetentionDisposalRecord {
  final String id;
  final String dataType; // 'evaluation', 'attendance', 'referral', etc.
  final String retentionPeriodDays;
  final DateTime disposalDate;
  final String disposalMethod; // 'permanent_delete', 'archive', 'anonymize'
  final int recordsDisposed;
  final String? disposedBy; // Admin who performed disposal
  final DateTime createdAt;

  RetentionDisposalRecord({
    required this.id,
    required this.dataType,
    required this.retentionPeriodDays,
    required this.disposalDate,
    required this.disposalMethod,
    required this.recordsDisposed,
    this.disposedBy,
    required this.createdAt,
  });

  factory RetentionDisposalRecord.fromMap(Map<String, dynamic> map) =>
      RetentionDisposalRecord(
        id: map['id'] ?? '',
        dataType: map['data_type'] ?? '',
        retentionPeriodDays: map['retention_period_days'] ?? '',
        disposalDate: DateTime.parse(
            map['disposal_date'] ?? DateTime.now().toIso8601String()),
        disposalMethod: map['disposal_method'] ?? '',
        recordsDisposed: map['records_disposed'] ?? 0,
        disposedBy: map['disposed_by'],
        createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'data_type': dataType,
    'retention_period_days': retentionPeriodDays,
    'disposal_date': disposalDate.toIso8601String(),
    'disposal_method': disposalMethod,
    'records_disposed': recordsDisposed,
    'disposed_by': disposedBy,
    'created_at': createdAt.toIso8601String(),
  };
}
