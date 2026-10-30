/// Concrete Repository Implementations
///
/// Specific repositories for each entity type using the generic RepositoryBase.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/canonical/index.dart';
import '../../core/database/repository_base.dart';
import '../../core/database/query_builder.dart';

// ============================================================================
// EVALUATION REPOSITORY
// ============================================================================

class EvaluationRepository extends RepositoryBase<EvaluationSession> {
  @override
  String get collectionName => 'evaluation_sessions';

  @override
  EvaluationSession fromJson(Map<String, dynamic> json) {
    return EvaluationSession.fromMap(json);
  }

  @override
  Map<String, dynamic> toJson(EvaluationSession entity) {
    return entity.toMap();
  }

  /// Get evaluations for a specific child
  Future<List<EvaluationSession>> getByChildId(String childId) async {
    final query = QueryBuilder(collectionName: collectionName)
        .whereChild(childId)
        .orderBy('createdAt', direction: SortDirection.descending);

    return await _loadAllFiltered(query);
  }

  /// Get evaluations by domain
  Future<List<EvaluationSession>> getByDomain(String domain) async {
    final query = QueryBuilder(collectionName: collectionName)
        .whereDomain(domain)
        .orderBy('createdAt', direction: SortDirection.descending);

    return await _loadAllFiltered(query);
  }

  /// Get pending evaluations
  Future<List<EvaluationSession>> getPending() async {
    final query = QueryBuilder(collectionName: collectionName)
        .whereStatus(['pending'])
        .orderBy('createdAt', direction: SortDirection.descending);

    return await _loadAllFiltered(query);
  }

  Future<List<EvaluationSession>> _loadAllFiltered(QueryBuilder query) async {
    var firestoreQuery = collection as Query;
    firestoreQuery = query.applyToFirestoreQuery(firestoreQuery);

    final snapshot = await firestoreQuery.get();
    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }
}

// ============================================================================
// REFERRAL REPOSITORY
// ============================================================================

class ReferralRepository extends RepositoryBase<Referral> {
  @override
  String get collectionName => 'referrals';

  @override
  Referral fromJson(Map<String, dynamic> json) {
    return Referral.fromMap(json);
  }

  @override
  Map<String, dynamic> toJson(Referral entity) {
    return entity.toMap();
  }

  /// Get referrals for a specific child
  Future<List<Referral>> getByChildId(String childId) async {
    final snapshot = await collection
        .where('childId', isEqualTo: childId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }

  /// Get active referrals
  Future<List<Referral>> getActive() async {
    final snapshot = await collection
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }

  /// Get referrals by status
  Future<List<Referral>> getByStatus(String status) async {
    final snapshot = await collection
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }
}

// ============================================================================
// ATTENDANCE REPOSITORY
// ============================================================================

class AttendanceRepository extends RepositoryBase<AttendanceEvent> {
  @override
  String get collectionName => 'attendance_events';

  @override
  AttendanceEvent fromJson(Map<String, dynamic> json) {
    return AttendanceEvent.fromMap(json);
  }

  @override
  Map<String, dynamic> toJson(AttendanceEvent entity) {
    return entity.toMap();
  }

  /// Get attendance for a specific child
  Future<List<AttendanceEvent>> getByChildId(String childId) async {
    final snapshot = await collection
        .where('childId', isEqualTo: childId)
        .orderBy('eventTime', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }

  /// Get attendance in date range
  Future<List<AttendanceEvent>> getInDateRange(
    DateTime start,
    DateTime end, {
    String? childId,
  }) async {
    var query = collection
        .where(
          'eventTime',
          isGreaterThanOrEqualTo: start,
          isLessThanOrEqualTo: end,
        )
        .orderBy('eventTime', descending: true);

    if (childId != null) {
      query = query.where('childId', isEqualTo: childId);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }
}

// ============================================================================
// CHILD REPOSITORY
// ============================================================================

class ChildRepository extends RepositoryBase<Child> {
  @override
  String get collectionName => 'children';

  @override
  Child fromJson(Map<String, dynamic> json) {
    return Child.fromMap(json);
  }

  @override
  Map<String, dynamic> toJson(Child entity) {
    return entity.toMap();
  }

  /// Get children at a center
  Future<List<Child>> getByCenterId(String centerId) async {
    final snapshot = await collection
        .where('centerId', isEqualTo: centerId)
        .where('status', isEqualTo: 'active')
        .orderBy('name')
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }

  /// Search children by name
  Future<List<Child>> searchByName(String query) async {
    // Note: Firestore doesn't support LIKE; this is case-sensitive prefix
    final snapshot = await collection
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: '$query\uf8ff')
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }
}

// ============================================================================
// USER REPOSITORY
// ============================================================================

class UserRepository extends RepositoryBase<CanonicalUser> {
  @override
  String get collectionName => 'users';

  @override
  CanonicalUser fromJson(Map<String, dynamic> json) {
    return CanonicalUser.fromMap(json);
  }

  @override
  Map<String, dynamic> toJson(CanonicalUser entity) {
    return entity.toMap();
  }

  /// Get user by email
  Future<CanonicalUser?> getByEmail(String email) async {
    final snapshot = await collection
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return fromJson({
      ...snapshot.docs.first.data() as Map<String, dynamic>,
      '__id': snapshot.docs.first.id,
    });
  }

  /// Get users by role
  Future<List<CanonicalUser>> getByRole(String role) async {
    final snapshot = await collection
        .where('role', isEqualTo: role)
        .orderBy('name')
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }

  /// Get teachers at a center
  Future<List<CanonicalUser>> getTeachersByCenterId(String centerId) async {
    final snapshot = await collection
        .where('role', isEqualTo: 'teacher')
        .where('centerId', isEqualTo: centerId)
        .orderBy('name')
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }
}

// ============================================================================
// NOTIFICATION REPOSITORY
// ============================================================================

class NotificationRepository extends RepositoryBase<Notification> {
  @override
  String get collectionName => 'notifications';

  @override
  Notification fromJson(Map<String, dynamic> json) {
    return Notification.fromMap(json);
  }

  @override
  Map<String, dynamic> toJson(Notification entity) {
    return entity.toMap();
  }

  /// Get unread notifications for user
  Future<List<Notification>> getUnreadForUser(String userId) async {
    final snapshot = await collection
        .where('recipientId', isEqualTo: userId)
        .where('readAt', isNull: true)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }

  /// Get all notifications for user
  Future<List<Notification>> getForUser(String userId) async {
    final snapshot = await collection
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }

  /// Mark as read
  Future<void> markAsRead(String notificationId) async {
    await updatePartial(notificationId, {
      'readAt': FieldValue.serverTimestamp(),
    });
  }
}

// ============================================================================
// AUDIT LOG REPOSITORY
// ============================================================================

class AuditLogRepository extends RepositoryBase<AuditLog> {
  @override
  String get collectionName => 'audit_logs';

  @override
  AuditLog fromJson(Map<String, dynamic> json) {
    return AuditLog.fromMap(json);
  }

  @override
  Map<String, dynamic> toJson(AuditLog entity) {
    return entity.toMap();
  }

  /// Get logs by actor
  Future<List<AuditLog>> getByActor(String actorId) async {
    final snapshot = await collection
        .where('actorId', isEqualTo: actorId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }

  /// Get logs by entity
  Future<List<AuditLog>> getByEntity(String entityType, String entityId) async {
    final snapshot = await collection
        .where('entityType', isEqualTo: entityType)
        .where('entityId', isEqualTo: entityId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }

  /// Get logs in date range
  Future<List<AuditLog>> getInDateRange(DateTime start, DateTime end) async {
    final snapshot = await collection
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: start,
          isLessThanOrEqualTo: end,
        )
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              fromJson({...doc.data() as Map<String, dynamic>, '__id': doc.id}),
        )
        .toList();
  }
}
