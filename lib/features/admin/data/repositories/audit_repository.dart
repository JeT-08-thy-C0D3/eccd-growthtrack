import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/audit_log_model.dart';

class AuditRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> logAction({
    required String action,
    String? performedBy,
    required String targetRecord,
  }) async {
    try {
      final user = _auth.currentUser;
      final actor = performedBy ?? user?.email ?? user?.uid ?? 'Admin/System';
      final now = DateTime.now();

      final docRef = _firestore.collection('audit_logs').doc();
      final logModel = AuditLogModel(
        id: docRef.id,
        action: action,
        performedBy: actor,
        targetRecord: targetRecord,
        timestamp: now,
      );

      await docRef.set(logModel.toMap(), SetOptions(merge: true));
    } catch (e) {
      print('AuditRepository logAction error: $e');
    }
  }

  Future<List<AuditLogModel>> getLogs({int? limit}) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('audit_logs')
        .orderBy('timestamp', descending: true);
    if (limit != null) query = query.limit(limit);
    final snapshot = await query.get();
    
    return snapshot.docs
        .map((doc) => AuditLogModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Stream<List<AuditLogModel>> streamLogs({int? limit}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('audit_logs')
        .orderBy('timestamp', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AuditLogModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
