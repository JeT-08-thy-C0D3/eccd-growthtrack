import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/file_upload_repository.dart';
import '../database/database_helper.dart';
import '../network/connectivity_service.dart';

class SyncEngine {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityService _connectivity = ConnectivityService();
  final FileUploadRepository _fileUploadRepo = FileUploadRepository();
  
  Timer? _syncTimer;
  bool _isSyncing = false;

  final List<String> _tablesToSync = [
    'users',
    'children',
    'attendance',
    'evaluations',
    'parent_feedback',
    'triangulations',
    'development_summaries',
    'activities',
    'activity_submissions',
    'referrals',
    'audit_logs',
    'clarifications',
  ];

  void start() {
    _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        performSync();
      }
    });

    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (await _connectivity.isOnline) {
        performSync();
      }
    });
  }

  void stop() {
    _syncTimer?.cancel();
  }

  Future<void> performSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      print("SyncEngine: Starting synchronization...");
      
      // 0. Sync pending file uploads to Supabase Storage
      await _fileUploadRepo.syncPendingFileUploads();

      // 1. Sync all database tables with Firestore
      for (var table in _tablesToSync) {
        await _syncTable(table, _getIdField(table));
      }

      print("SyncEngine: Synchronization complete.");
    } catch (e) {
      print("SyncEngine Error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncTable(String tableName, String idField) async {
    final db = await _dbHelper.database;

    // A. Upstream: Local (SQLite) -> Remote (Cloud Firestore)
    final unsynced = await db.query(tableName, where: 'is_synced = ?', whereArgs: [0]);
    for (var row in unsynced) {
      try {
        final String docId = row[idField].toString();
        final uploadData = Map<String, dynamic>.from(row);
        uploadData.remove('is_synced');
        uploadData.remove('id');

        await _firestore.collection(tableName).doc(docId).set(uploadData, SetOptions(merge: true));
        await db.update(tableName, {'is_synced': 1}, where: '$idField = ?', whereArgs: [row[idField]]);
      } catch (e) {
        print("Upstream Sync Error [$tableName]: $e");
      }
    }

    // B. Downstream: Remote (Cloud Firestore) -> Local (SQLite) with Conflict Resolution
    try {
      final querySnapshot = await _firestore.collection(tableName).get();
      for (var doc in querySnapshot.docs) {
        final remoteData = doc.data();
        final String docId = doc.id;

        final localData = await db.query(tableName, where: '$idField = ?', whereArgs: [docId]);

        if (localData.isEmpty) {
          // New record from cloud
          await db.insert(tableName, {...remoteData, idField: docId, 'is_synced': 1});
        } else {
          // Conflict Resolution: Latest 'updated_at' wins (LWW)
          final remoteUpdatedAt = DateTime.tryParse(remoteData['updated_at'] as String? ?? '') ?? DateTime(1970);
          final localUpdatedAt = DateTime.tryParse(localData.first['updated_at'] as String? ?? localData.first['created_at'] as String? ?? '') ?? DateTime(1970);

          if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
            await db.update(tableName, {...remoteData, 'is_synced': 1}, where: '$idField = ?', whereArgs: [docId]);
          }
        }
      }
    } catch (e) {
      print("Downstream Sync Error [$tableName]: $e");
    }
  }

  String _getIdField(String table) {
    if (table == 'children') return 'child_id';
    if (table == 'users') return 'uid';
    if (table == 'file_uploads') return 'file_id';
    return 'id';
  }
}
