import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../database/database_helper.dart';
import '../network/connectivity_service.dart';

class SyncEngine {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityService _connectivity = ConnectivityService();
  
  Timer? _syncTimer;
  bool _isSyncing = false;

  void start() {
    // Sync whenever connection is restored
    _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        performSync();
      }
    });

    // Also periodic sync every 5 minutes if online
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
      
      // 1. Sync Children
      await _syncTable('children', 'child_id');
      
      // 2. Sync Users
      await _syncTable('users', 'uid');

      // 3. Sync Evaluations
      await _syncTable('evaluations', 'id');

      // 4. Sync Referrals
      await _syncTable('referrals', 'id');

      print("SyncEngine: Synchronization complete.");
    } catch (e) {
      print("SyncEngine Error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncTable(String tableName, String idField) async {
    final db = await _dbHelper.database;

    // A. Upstream: Local -> Remote (Unsynced changes)
    final unsynced = await db.query(tableName, where: 'is_synced = ?', whereArgs: [0]);
    for (var row in unsynced) {
      final String docId = row[idField].toString();
      await _firestore.collection(tableName).doc(docId).set(row, SetOptions(merge: true));
      await db.update(tableName, {'is_synced': 1}, where: '$idField = ?', whereArgs: [row[idField]]);
    }

    // B. Downstream: Remote -> Local (Latest updates)
    // In a real app, we'd use a 'last_sync_timestamp' to only fetch new things.
    // For this prototype, we'll fetch based on 'updated_at'.
    final querySnapshot = await _firestore.collection(tableName).get();
    for (var doc in querySnapshot.docs) {
      final remoteData = doc.data();
      final String docId = doc.id;

      final localData = await db.query(tableName, where: '$idField = ?', whereArgs: [docId]);

      if (localData.isEmpty) {
        // New record from cloud
        await db.insert(tableName, {...remoteData, 'is_synced': 1});
      } else {
        // Conflict resolution: Latest update wins
        final remoteUpdatedAt = DateTime.parse(remoteData['updated_at']);
        final localUpdatedAt = DateTime.parse(localData.first['updated_at'] as String);

        if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
          await db.update(tableName, {...remoteData, 'is_synced': 1}, where: '$idField = ?', whereArgs: [docId]);
        }
      }
    }
  }
}
