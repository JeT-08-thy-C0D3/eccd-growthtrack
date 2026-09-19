import 'package:firebase_auth/firebase_auth.dart';
import '../../data/datasources/local_data_source.dart';
import '../../core/network/connectivity_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogger {
  static final LocalDataSource _local = LocalDataSource();
  static final ConnectivityService _connectivity = ConnectivityService();
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> log({
    required String action,
    required String module,
    required String description,
  }) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      final timestamp = DateTime.now().toIso8601String();

      final logData = {
        'user_id': userId ?? 'Anonymous',
        'action': action,
        'module': module,
        'description': description,
        'timestamp': timestamp,
      };

      // 1. Save Locally
      await _local.saveRecord('audit_logs', logData);

      // 2. Attempt Cloud Save if Online
      if (await _connectivity.isOnline) {
        await _firestore.collection('audit_logs').add(logData);
        // Note: For simplicity, I'm not marking it as synced here because
        // we'd need the local ID. The SyncService will handle it.
      }
    } catch (e) {
      print('AuditLogger Error: $e');
    }
  }
}
