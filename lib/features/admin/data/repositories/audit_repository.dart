import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/audit_log_model.dart';

class AuditRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<AuditLogModel>> getLogs() async {
    final query = await _firestore
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .get();
    
    return query.docs
        .map((doc) => AuditLogModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Stream<List<AuditLogModel>> streamLogs() {
    return _firestore
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AuditLogModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
