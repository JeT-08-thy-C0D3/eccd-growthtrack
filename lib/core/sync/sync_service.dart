import 'dart:async';
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
    'clarifications'
  ];

  void init() {
    _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) performSync();
    });

    Timer.periodic(const Duration(minutes: 10), (timer) async {
      if (await _connectivity.isOnline) performSync();
    });
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

    // 1. UPLOAD (Local -> Cloud)
    final unsynced = await _local.getUnsyncedRecords(table);
    for (var row in unsynced) {
      try {
        final docId = row[idField].toString();
        await _remote.uploadRecord(table, docId, row);
        await _local.markAsSynced(table, row[idField]);
      } catch (e) {
        print("UPLOAD ERROR [$table]: $e");
      }
    }

    // 2. DOWNLOAD (Cloud -> Local) - Simplistic "fetch all" for prototype
    try {
      final updates = await _remote.fetchUpdates(table, '1970-01-01'); 
      for (var doc in updates) {
        final remoteData = doc.data();
        await _local.saveRecord(table, remoteData, isFromRemote: true);
      }
    } catch (e) {
      print("DOWNLOAD ERROR [$table]: $e");
    }
  }

  String _getIdField(String table) {
    if (table == 'children') return 'child_id';
    if (table == 'users') return 'uid';
    return 'id';
  }
}
