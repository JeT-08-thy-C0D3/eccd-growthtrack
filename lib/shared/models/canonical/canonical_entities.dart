/// Canonical models for remaining 15+ entities required by Phase 1.
library;

// ============================================================================
// CENTER & CHILD MANAGEMENT
// ============================================================================

class Center {
  final String id;
  final String name;
  final String? description;
  final String region; // Region/district
  final String? address;
  final String? phone;
  final String? email;
  final String status; // 'active', 'inactive'
  final DateTime createdAt;
  final DateTime updatedAt;

  Center({
    required this.id,
    required this.name,
    this.description,
    required this.region,
    this.address,
    this.phone,
    this.email,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Center.fromMap(Map<String, dynamic> map) => Center(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'],
    region: map['region'] ?? '',
    address: map['address'],
    phone: map['phone'],
    email: map['email'],
    status: map['status'] ?? 'active',
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'region': region,
    'address': address,
    'phone': phone,
    'email': email,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class Child {
  final String id;
  final String name;
  final DateTime dateOfBirth;
  final String gender; // 'male', 'female', 'other'
  final String centerId; // Reference to Center
  final String? guardianId; // Primary parent/guardian
  final String status; // 'active', 'inactive', 'transferred'
  final String? enrollmentNumber;
  final String? healthInsuranceNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  Child({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    required this.centerId,
    this.guardianId,
    this.status = 'active',
    this.enrollmentNumber,
    this.healthInsuranceNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Child.fromMap(Map<String, dynamic> map) => Child(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    dateOfBirth: DateTime.parse(map['date_of_birth'] ?? DateTime.now().toIso8601String()),
    gender: map['gender'] ?? 'other',
    centerId: map['center_id'] ?? '',
    guardianId: map['guardian_id'],
    status: map['status'] ?? 'active',
    enrollmentNumber: map['enrollment_number'],
    healthInsuranceNumber: map['health_insurance_number'],
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'date_of_birth': dateOfBirth.toIso8601String(),
    'gender': gender,
    'center_id': centerId,
    'guardian_id': guardianId,
    'status': status,
    'enrollment_number': enrollmentNumber,
    'health_insurance_number': healthInsuranceNumber,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class ChildAssignment {
  final String id;
  final String childId;
  final String teacherId;
  final String centerId;
  final DateTime assignmentDate;
  final DateTime? unassignmentDate;
  final String status; // 'active', 'inactive'
  final DateTime createdAt;

  ChildAssignment({
    required this.id,
    required this.childId,
    required this.teacherId,
    required this.centerId,
    required this.assignmentDate,
    this.unassignmentDate,
    this.status = 'active',
    required this.createdAt,
  });

  factory ChildAssignment.fromMap(Map<String, dynamic> map) => ChildAssignment(
    id: map['id'] ?? '',
    childId: map['child_id'] ?? '',
    teacherId: map['teacher_id'] ?? '',
    centerId: map['center_id'] ?? '',
    assignmentDate: DateTime.parse(map['assignment_date'] ?? DateTime.now().toIso8601String()),
    unassignmentDate: map['unassignment_date'] != null
        ? DateTime.parse(map['unassignment_date'] as String)
        : null,
    status: map['status'] ?? 'active',
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'child_id': childId,
    'teacher_id': teacherId,
    'center_id': centerId,
    'assignment_date': assignmentDate.toIso8601String(),
    'unassignment_date': unassignmentDate?.toIso8601String(),
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}

// ============================================================================
// PRIVACY & CONSENT
// ============================================================================

class ConsentRecord {
  final String id;
  final String parentId;
  final String childId;
  final String noticeVersion;
  final List<String> purposes; // e.g., ['evaluation', 'reporting', 'research']
  final String legalBasis; // e.g., 'parental_consent', 'legitimate_interest'
  final String? relationship; // 'parent', 'guardian', 'custodian'
  final bool isGiven;
  final DateTime consentDate;
  final DateTime? withdrawalDate;
  final String? deviceInfo;
  final String? sessionInfo;
  final DateTime createdAt;

  ConsentRecord({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.noticeVersion,
    required this.purposes,
    required this.legalBasis,
    this.relationship,
    this.isGiven = true,
    required this.consentDate,
    this.withdrawalDate,
    this.deviceInfo,
    this.sessionInfo,
    required this.createdAt,
  });

  factory ConsentRecord.fromMap(Map<String, dynamic> map) => ConsentRecord(
    id: map['id'] ?? '',
    parentId: map['parent_id'] ?? '',
    childId: map['child_id'] ?? '',
    noticeVersion: map['notice_version'] ?? '1.0',
    purposes: List<String>.from(map['purposes'] as List? ?? []),
    legalBasis: map['legal_basis'] ?? '',
    relationship: map['relationship'],
    isGiven: (map['is_given'] ?? 1) == 1,
    consentDate: DateTime.parse(map['consent_date'] ?? DateTime.now().toIso8601String()),
    withdrawalDate: map['withdrawal_date'] != null
        ? DateTime.parse(map['withdrawal_date'] as String)
        : null,
    deviceInfo: map['device_info'],
    sessionInfo: map['session_info'],
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'parent_id': parentId,
    'child_id': childId,
    'notice_version': noticeVersion,
    'purposes': purposes,
    'legal_basis': legalBasis,
    'relationship': relationship,
    'is_given': isGiven ? 1 : 0,
    'consent_date': consentDate.toIso8601String(),
    'withdrawal_date': withdrawalDate?.toIso8601String(),
    'device_info': deviceInfo,
    'session_info': sessionInfo,
    'created_at': createdAt.toIso8601String(),
  };
}

// ============================================================================
// ACTIVITIES & OBSERVATIONS
// ============================================================================

class AutomatedActivityAttempt {
  final String id;
  final String childId;
  final String activityType; // 'matching', 'recognition', 'drag_drop', 'counting', 'tracing', 'shape'
  final int attemptNumber;
  final int score;
  final int timeSpentSeconds;
  final String assistanceLevel; // 'none', 'verbal', 'physical', 'full'
  final String? evidence; // JSON or URL to evidence
  final double confidence; // 0.0-1.0
  final bool teacherConfirmed;
  final DateTime createdAt;

  AutomatedActivityAttempt({
    required this.id,
    required this.childId,
    required this.activityType,
    required this.attemptNumber,
    required this.score,
    required this.timeSpentSeconds,
    required this.assistanceLevel,
    this.evidence,
    this.confidence = 0.5,
    this.teacherConfirmed = false,
    required this.createdAt,
  });

  factory AutomatedActivityAttempt.fromMap(Map<String, dynamic> map) => AutomatedActivityAttempt(
    id: map['id'] ?? '',
    childId: map['child_id'] ?? '',
    activityType: map['activity_type'] ?? '',
    attemptNumber: map['attempt_number'] ?? 0,
    score: map['score'] ?? 0,
    timeSpentSeconds: map['time_spent_seconds'] ?? 0,
    assistanceLevel: map['assistance_level'] ?? 'none',
    evidence: map['evidence'],
    confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
    teacherConfirmed: (map['teacher_confirmed'] ?? 0) == 1,
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'child_id': childId,
    'activity_type': activityType,
    'attempt_number': attemptNumber,
    'score': score,
    'time_spent_seconds': timeSpentSeconds,
    'assistance_level': assistanceLevel,
    'evidence': evidence,
    'confidence': confidence,
    'teacher_confirmed': teacherConfirmed ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };
}

class AttendanceEvent {
  final String id;
  final String childId;
  final String centerId;
  final DateTime attendanceDate;
  final String status; // 'present', 'absent', 'late', 'excused'
  final String? rfidTagId; // If RFID-scanned
  final String? recordedBy; // Teacher/admin who recorded
  final DateTime createdAt;

  AttendanceEvent({
    required this.id,
    required this.childId,
    required this.centerId,
    required this.attendanceDate,
    required this.status,
    this.rfidTagId,
    this.recordedBy,
    required this.createdAt,
  });

  factory AttendanceEvent.fromMap(Map<String, dynamic> map) => AttendanceEvent(
    id: map['id'] ?? '',
    childId: map['child_id'] ?? '',
    centerId: map['center_id'] ?? '',
    attendanceDate: DateTime.parse(map['attendance_date'] ?? DateTime.now().toIso8601String()),
    status: map['status'] ?? 'present',
    rfidTagId: map['rfid_tag_id'],
    recordedBy: map['recorded_by'],
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'child_id': childId,
    'center_id': centerId,
    'attendance_date': attendanceDate.toIso8601String(),
    'status': status,
    'rfid_tag_id': rfidTagId,
    'recorded_by': recordedBy,
    'created_at': createdAt.toIso8601String(),
  };
}

// ============================================================================
// REFERRAL & FEEDBACK
// ============================================================================

class Referral {
  final String id;
  final String childId;
  final String referrerId; // Teacher/user making referral
  final String centerId;
  final String concern; // Type of concern
  final String? description;
  final String status; // 'draft', 'submitted', 'acknowledged', 'closed'
  final DateTime referralDate;
  final String? referralAgency;
  final String? outcome;
  final DateTime? closedDate;
  final DateTime createdAt;

  Referral({
    required this.id,
    required this.childId,
    required this.referrerId,
    required this.centerId,
    required this.concern,
    this.description,
    this.status = 'draft',
    required this.referralDate,
    this.referralAgency,
    this.outcome,
    this.closedDate,
    required this.createdAt,
  });

  factory Referral.fromMap(Map<String, dynamic> map) => Referral(
    id: map['id'] ?? '',
    childId: map['child_id'] ?? '',
    referrerId: map['referrer_id'] ?? '',
    centerId: map['center_id'] ?? '',
    concern: map['concern'] ?? '',
    description: map['description'],
    status: map['status'] ?? 'draft',
    referralDate: DateTime.parse(map['referral_date'] ?? DateTime.now().toIso8601String()),
    referralAgency: map['referral_agency'],
    outcome: map['outcome'],
    closedDate: map['closed_date'] != null
        ? DateTime.parse(map['closed_date'] as String)
        : null,
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'child_id': childId,
    'referrer_id': referrerId,
    'center_id': centerId,
    'concern': concern,
    'description': description,
    'status': status,
    'referral_date': referralDate.toIso8601String(),
    'referral_agency': referralAgency,
    'outcome': outcome,
    'closed_date': closedDate?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

class ParentFeedback {
  final String id;
  final String parentId;
  final String childId;
  final String content;
  final String? feedbackCategory; // Type of feedback
  final bool isAnonymous;
  final DateTime createdAt;

  ParentFeedback({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.content,
    this.feedbackCategory,
    this.isAnonymous = false,
    required this.createdAt,
  });

  factory ParentFeedback.fromMap(Map<String, dynamic> map) => ParentFeedback(
    id: map['id'] ?? '',
    parentId: map['parent_id'] ?? '',
    childId: map['child_id'] ?? '',
    content: map['content'] ?? '',
    feedbackCategory: map['feedback_category'],
    isAnonymous: (map['is_anonymous'] ?? 0) == 1,
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'parent_id': parentId,
    'child_id': childId,
    'content': content,
    'feedback_category': feedbackCategory,
    'is_anonymous': isAnonymous ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };
}

// ============================================================================
// OTHER ENTITIES
// ============================================================================

class HomeActivity {
  final String id;
  final String childId;
  final String activityTitle;
  final String? description;
  final String? assignedBy; // Teacher ID
  final DateTime dueDate;
  final bool completed;
  final DateTime? completedDate;
  final DateTime createdAt;

  HomeActivity({
    required this.id,
    required this.childId,
    required this.activityTitle,
    this.description,
    this.assignedBy,
    required this.dueDate,
    this.completed = false,
    this.completedDate,
    required this.createdAt,
  });

  factory HomeActivity.fromMap(Map<String, dynamic> map) => HomeActivity(
    id: map['id'] ?? '',
    childId: map['child_id'] ?? '',
    activityTitle: map['activity_title'] ?? '',
    description: map['description'],
    assignedBy: map['assigned_by'],
    dueDate: DateTime.parse(map['due_date'] ?? DateTime.now().toIso8601String()),
    completed: (map['completed'] ?? 0) == 1,
    completedDate: map['completed_date'] != null
        ? DateTime.parse(map['completed_date'] as String)
        : null,
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'child_id': childId,
    'activity_title': activityTitle,
    'description': description,
    'assigned_by': assignedBy,
    'due_date': dueDate.toIso8601String(),
    'completed': completed ? 1 : 0,
    'completed_date': completedDate?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

class ClarificationRequest {
  final String id;
  final String parentId;
  final String childId;
  final String question;
  final String? response;
  final String status; // 'pending', 'answered', 'resolved'
  final DateTime createdAt;
  final DateTime? answeredAt;

  ClarificationRequest({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.question,
    this.response,
    this.status = 'pending',
    required this.createdAt,
    this.answeredAt,
  });

  factory ClarificationRequest.fromMap(Map<String, dynamic> map) => ClarificationRequest(
    id: map['id'] ?? '',
    parentId: map['parent_id'] ?? '',
    childId: map['child_id'] ?? '',
    question: map['question'] ?? '',
    response: map['response'],
    status: map['status'] ?? 'pending',
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    answeredAt: map['answered_at'] != null
        ? DateTime.parse(map['answered_at'] as String)
        : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'parent_id': parentId,
    'child_id': childId,
    'question': question,
    'response': response,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'answered_at': answeredAt?.toIso8601String(),
  };
}

class Notification {
  final String id;
  final String userId;
  final String type;
  final String? title;
  final String message;
  final int priority; // 0-5, higher = more important
  final String? deduplicationKey;
  final bool read;
  final DateTime? readAt;
  final DateTime? expiresAt;
  final String? deepLink;
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.userId,
    required this.type,
    this.title,
    required this.message,
    this.priority = 2,
    this.deduplicationKey,
    this.read = false,
    this.readAt,
    this.expiresAt,
    this.deepLink,
    required this.createdAt,
  });

  factory Notification.fromMap(Map<String, dynamic> map) => Notification(
    id: map['id'] ?? '',
    userId: map['user_id'] ?? '',
    type: map['type'] ?? '',
    title: map['title'],
    message: map['message'] ?? '',
    priority: map['priority'] ?? 2,
    deduplicationKey: map['deduplication_key'],
    read: (map['read'] ?? 0) == 1,
    readAt: map['read_at'] != null
        ? DateTime.parse(map['read_at'] as String)
        : null,
    expiresAt: map['expires_at'] != null
        ? DateTime.parse(map['expires_at'] as String)
        : null,
    deepLink: map['deep_link'],
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'type': type,
    'title': title,
    'message': message,
    'priority': priority,
    'deduplication_key': deduplicationKey,
    'read': read ? 1 : 0,
    'read_at': readAt?.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'deep_link': deepLink,
    'created_at': createdAt.toIso8601String(),
  };
}

class AuditLog {
  final String id;
  final String? userId;
  final String action; // 'create', 'update', 'delete', 'read'
  final String entityType; // 'evaluation', 'child', 'referral', etc.
  final String? entityId;
  final String? module; // Feature module where action occurred
  final String? oldValue;
  final String? newValue;
  final String? reason;
  final DateTime createdAt;

  AuditLog({
    required this.id,
    this.userId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.module,
    this.oldValue,
    this.newValue,
    this.reason,
    required this.createdAt,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
    id: map['id'] ?? '',
    userId: map['user_id'],
    action: map['action'] ?? '',
    entityType: map['entity_type'] ?? '',
    entityId: map['entity_id'],
    module: map['module'],
    oldValue: map['old_value'],
    newValue: map['new_value'],
    reason: map['reason'],
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'action': action,
    'entity_type': entityType,
    'entity_id': entityId,
    'module': module,
    'old_value': oldValue,
    'new_value': newValue,
    'reason': reason,
    'created_at': createdAt.toIso8601String(),
  };
}

class RfidDevice {
  final String id;
  final String centerId;
  final String deviceName;
  final String serialNumber;
  final String transportType; // 'ble', 'usb', 'serial', 'wifi'
  final String status; // 'active', 'inactive', 'maintenance'
  final DateTime createdAt;

  RfidDevice({
    required this.id,
    required this.centerId,
    required this.deviceName,
    required this.serialNumber,
    required this.transportType,
    this.status = 'active',
    required this.createdAt,
  });

  factory RfidDevice.fromMap(Map<String, dynamic> map) => RfidDevice(
    id: map['id'] ?? '',
    centerId: map['center_id'] ?? '',
    deviceName: map['device_name'] ?? '',
    serialNumber: map['serial_number'] ?? '',
    transportType: map['transport_type'] ?? 'ble',
    status: map['status'] ?? 'active',
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'center_id': centerId,
    'device_name': deviceName,
    'serial_number': serialNumber,
    'transport_type': transportType,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}

class RfidTag {
  final String id;
  final String childId;
  final String tagNumber;
  final String status; // 'active', 'lost', 'inactive'
  final DateTime enrolledAt;
  final DateTime? deactivatedAt;

  RfidTag({
    required this.id,
    required this.childId,
    required this.tagNumber,
    this.status = 'active',
    required this.enrolledAt,
    this.deactivatedAt,
  });

  factory RfidTag.fromMap(Map<String, dynamic> map) => RfidTag(
    id: map['id'] ?? '',
    childId: map['child_id'] ?? '',
    tagNumber: map['tag_number'] ?? '',
    status: map['status'] ?? 'active',
    enrolledAt: DateTime.parse(map['enrolled_at'] ?? DateTime.now().toIso8601String()),
    deactivatedAt: map['deactivated_at'] != null
        ? DateTime.parse(map['deactivated_at'] as String)
        : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'child_id': childId,
    'tag_number': tagNumber,
    'status': status,
    'enrolled_at': enrolledAt.toIso8601String(),
    'deactivated_at': deactivatedAt?.toIso8601String(),
  };
}

class SyncOutboxItem {
  final String id;
  final String entityType;
  final String entityId;
  final String operation; // 'create', 'update', 'delete'
  final Map<String, dynamic> payload;
  final String operationId; // For idempotency
  final bool tombstone; // Mark as deleted if true
  final int retryCount;
  final String status; // 'pending', 'synced', 'failed'
  final DateTime createdAt;
  final DateTime? syncedAt;

  SyncOutboxItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.operationId,
    this.tombstone = false,
    this.retryCount = 0,
    this.status = 'pending',
    required this.createdAt,
    this.syncedAt,
  });

  factory SyncOutboxItem.fromMap(Map<String, dynamic> map) => SyncOutboxItem(
    id: map['id'] ?? '',
    entityType: map['entity_type'] ?? '',
    entityId: map['entity_id'] ?? '',
    operation: map['operation'] ?? '',
    payload: map['payload'] ?? {},
    operationId: map['operation_id'] ?? '',
    tombstone: (map['tombstone'] ?? 0) == 1,
    retryCount: map['retry_count'] ?? 0,
    status: map['status'] ?? 'pending',
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    syncedAt: map['synced_at'] != null
        ? DateTime.parse(map['synced_at'] as String)
        : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'entity_type': entityType,
    'entity_id': entityId,
    'operation': operation,
    'payload': payload,
    'operation_id': operationId,
    'tombstone': tombstone ? 1 : 0,
    'retry_count': retryCount,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'synced_at': syncedAt?.toIso8601String(),
  };
}
