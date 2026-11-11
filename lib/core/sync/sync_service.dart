import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/local_data_source.dart';
import '../../data/datasources/remote_data_source.dart';
import '../../data/repositories/file_upload_repository.dart';
import '../network/connectivity_service.dart';

class SyncService {
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();
  final FileUploadRepository _fileUploadRepo = FileUploadRepository();

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

  void init() {
    _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) performSync();
    });

    Timer.periodic(const Duration(minutes: 10), (timer) async {
      if (await _connectivity.isOnline) performSync();
    });

    // Start a non-blocking inbox/outbox sync at launch. Dashboards can render
    // their SQLite cache immediately while fresh Firestore records download.
    unawaited(performSync());
  }

  Future<void> performSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      print("SYNC ENGINE: Starting synchronization...");
      // 0. Sync pending file uploads first
      await _fileUploadRepo.syncPendingFileUploads();

      for (String table in _tablesToSync) {
        await _syncTable(table);
      }
      print("SYNC ENGINE: Process complete.");
    } catch (e) {
      print("SYNC ENGINE ERROR: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncTable(String table) async {
    final String idField = _getIdField(table);
    final String collection = _collectionForTable(table);

    // 1. UPLOAD (Local -> Cloud)
    final unsynced = await _local.getUnsyncedRecords(table);
    for (var row in unsynced) {
      try {
        // Migration path for offline records created before RFID attendance.
        // Assigning this once preserves the original record and gives retries a
        // stable Firestore document instead of duplicating attendance.
        if (table == 'attendance' &&
            (row['attendance_event_id'] as String? ?? '').isEmpty) {
          final legacyId = 'legacy-attendance-${row['id']}';
          row['attendance_event_id'] = legacyId;
          await _local.saveRecord(table, row);
        }
        final docId = row[idField].toString();
        await _remote.uploadRecord(collection, docId, row);
        await _local.markAsSynced(table, row[idField]);
      } catch (e) {
        print("UPLOAD ERROR [$table]: $e");
      }
    }

    // 2. DOWNLOAD (Cloud -> Local) - Incremental sync using last_sync_timestamp
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncKey = 'last_sync_$table';
      final lastSyncDate =
          prefs.getString(lastSyncKey) ?? '1970-01-01T00:00:00.000';

      final updates = await _remote.fetchUpdates(collection, lastSyncDate);
      for (var doc in updates) {
        final remoteData = doc.data();
        // The Firestore document ID is the stable local ID for activities and
        // submissions. Older documents may not contain an `id` field because
        // it was previously stripped before upload, so restore it here before
        // LocalDataSource performs its upsert.
        if ((table == 'activities' || table == 'activity_submissions') &&
            !remoteData.containsKey('id')) {
          final localId = int.tryParse(doc.id);
          if (localId != null) remoteData['id'] = localId;
        }
        await _local.saveRecord(table, remoteData, isFromRemote: true);
      }

      await prefs.setString(lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print("DOWNLOAD ERROR [$table]: $e");
    }
  }

  String _getIdField(String table) {
    if (table == 'children') return 'child_id';
    if (table == 'users') return 'uid';
    if (table == 'attendance') return 'attendance_event_id';
    if (table == 'file_uploads') return 'file_id';
    return 'id';
  }

  String _collectionForTable(String table) =>
      table == 'attendance' ? 'attendance_events' : table;
}
