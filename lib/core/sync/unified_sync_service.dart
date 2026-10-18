/// Unified Synchronization Service (Consolidated)
/// 
/// This service consolidates sync_service.dart and sync_engine.dart into
/// a single, unified sync system with:
/// - Outbox/inbox pattern for offline-first sync
/// - Operation IDs for idempotency
/// - Tombstones for deletes
/// - Server timestamps
/// - Conflict resolution
/// - Retry and failure handling
/// - Visible sync status

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../database/database_helper.dart';
import '../../shared/models/canonical/canonical_entities.dart';

enum SyncStatus { idle, syncing, error, conflictDetected }
enum ConflictResolution { clientWins, serverWins, manual }

class UnifiedSyncService {
  static final UnifiedSyncService _instance = UnifiedSyncService._init();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncTime;
  int _pendingOperations = 0;
  List<String> _failedOperationIds = [];
  
  final List<VoidCallback> _statusListeners = [];
  final List<void Function(String)> _errorListeners = [];

  UnifiedSyncService._init();

  factory UnifiedSyncService() => _instance;

  // ============================================================================
  // STATUS & LISTENERS
  // ============================================================================

  /// Current sync status
  SyncStatus get status => _status;

  /// Number of pending sync operations
  int get pendingOperations => _pendingOperations;

  /// Last successful sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Subscribe to sync status changes
  void onStatusChanged(VoidCallback callback) {
    _statusListeners.add(callback);
  }

  /// Subscribe to sync errors
  void onError(void Function(String) callback) {
    _errorListeners.add(callback);
  }

  // ============================================================================
  // MAIN SYNC FLOW
  // ============================================================================

  /// Initialize sync service and check for pending operations
  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        // Web uses Firestore directly, no local sync
        print('✓ Web platform: using Firestore persistence');
        return;
      }

      // Load pending operations from local database
      _pendingOperations = await _dbHelper.getPendingSyncCount();
      
      if (_pendingOperations > 0) {
        print('⚠️ Found $_pendingOperations pending sync operations');
      }
    } catch (e) {
      _notifyError('Sync initialization error: $e');
    }
  }

  /// Perform full sync (upload pending, download updates)
  Future<void> sync() async {
    if (_status == SyncStatus.syncing) {
      print('⚠️ Sync already in progress');
      return;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      // Step 1: Upload local changes (outbox)
      await _uploadPendingChanges();

      // Step 2: Download remote updates (inbox)
      await _downloadRemoteUpdates();

      // Step 3: Apply changes locally
      await _applyRemoteChanges();

      _lastSyncTime = DateTime.now();
      _updateStatus(SyncStatus.idle);
      print('✓ Sync completed successfully');
    } catch (e) {
      _updateStatus(SyncStatus.error);
      _notifyError('Sync failed: $e');
      rethrow;
    }
  }

  /// Retry failed operations
  Future<void> retrySyncFailures() async {
    if (_failedOperationIds.isEmpty) return;

    print('↻ Retrying ${_failedOperationIds.length} failed operations...');
    
    for (final opId in _failedOperationIds) {
      try {
        await _retryOperation(opId);
        _failedOperationIds.remove(opId);
      } catch (e) {
        print('⚠️ Retry failed for $opId: $e');
      }
    }
  }

  // ============================================================================
  // OUTBOX: LOCAL CHANGES → FIRESTORE
  // ============================================================================

  /// Record a local change for sync
  Future<void> recordLocalChange({
    required String entityType,
    required String entityId,
    required String operation, // 'create', 'update', 'delete'
    required Map<String, dynamic> payload,
  }) async {
    if (kIsWeb) {
      // Web syncs immediately
      await _syncDirectToFirestore(entityType, entityId, operation, payload);
      return;
    }

    // Mobile: add to outbox for batch sync
    final operationId = _generateOperationId(entityType, entityId, operation);
    
    final outboxItem = SyncOutboxItem(
      id: operationId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      operationId: operationId,
      tombstone: operation == 'delete',
      retryCount: 0,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    try {
      // Store in local database
      await _dbHelper.insertSyncOutboxItem(outboxItem);
      _pendingOperations++;
      _updateStatus(SyncStatus.idle); // Indicate pending work
      
      print('✓ Recorded $operation for $entityType/$entityId');
    } catch (e) {
      _notifyError('Failed to record local change: $e');
      rethrow;
    }
  }

  /// Upload all pending changes to Firestore
  Future<void> _uploadPendingChanges() async {
    if (kIsWeb) return; // Web doesn't need outbox

    try {
      final outboxItems = await _dbHelper.getPendingSyncOutboxItems();
      
      for (final item in outboxItems) {
        try {
          await _syncOutboxItemToFirestore(item);
          
          // Mark as synced in local database
          await _dbHelper.updateSyncOutboxItemStatus(
            item.id,
            'synced',
            DateTime.now(),
          );
          
          _pendingOperations--;
        } catch (e) {
          // Mark as failed, increment retry count
          await _dbHelper.incrementOutboxRetryCount(item.id);
          _failedOperationIds.add(item.id);
          print('⚠️ Failed to sync $item.entityType/$item.entityId: $e');
        }
      }
    } catch (e) {
      print('Error uploading pending changes: $e');
      rethrow;
    }
  }

  /// Sync single outbox item to Firestore
  Future<void> _syncOutboxItemToFirestore(SyncOutboxItem item) async {
    final collection = _getFirestoreCollection(item.entityType);
    final docRef = _firestore.collection(collection).doc(item.entityId);

    switch (item.operation) {
      case 'create':
      case 'update':
        // Merge with server data (server timestamp override)
        await docRef.set(
          {
            ...item.payload,
            'updatedAt': FieldValue.serverTimestamp(),
            'isSynced': true,
            'syncedToFirestore': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        break;

      case 'delete':
        // Soft delete: mark as deleted, keep audit trail
        await docRef.update({
          'status': 'deleted',
          'deletedAt': FieldValue.serverTimestamp(),
          'tombstone': true,
        });
        break;
    }
  }

  // ============================================================================
  // INBOX: FIRESTORE → LOCAL
  // ============================================================================

  /// Download remote updates
  Future<void> _downloadRemoteUpdates() async {
    try {
      final collections = [
        'evaluation_sessions',
        'referrals',
        'attendance_events',
        'notifications',
        'categories',
      ];

      for (final collection in collections) {
        await _downloadCollectionUpdates(collection);
      }
    } catch (e) {
      print('Error downloading remote updates: $e');
      rethrow;
    }
  }

  /// Download updates for specific collection
  Future<void> _downloadCollectionUpdates(String collection) async {
    if (kIsWeb) return; // Web doesn't cache

    try {
      final query = _lastSyncTime != null
          ? _firestore
              .collection(collection)
              .where('updatedAt', isGreaterThan: _lastSyncTime)
          : _firestore.collection(collection).limit(100);

      final snapshot = await query.get();

      for (final doc in snapshot.docs) {
        // Store/update in local database
        await _dbHelper.cacheRemoteData(collection, doc.data());
      }

      print('✓ Downloaded ${snapshot.docs.length} updates from $collection');
    } catch (e) {
      print('Error downloading $collection: $e');
    }
  }

  /// Apply remote changes locally
  Future<void> _applyRemoteChanges() async {
    if (kIsWeb) return; // Web doesn't cache

    // TODO: Implement change detection and application
    // This would include conflict resolution logic
  }

  // ============================================================================
  // CONFLICT RESOLUTION
  // ============================================================================

  /// Detect and resolve conflicts
  Future<ConflictResolution> _resolveConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
  }) async {
    // Default strategy: server wins (remote is authoritative)
    // Can be overridden per entity type

    final localVersion = localData['version'] as int? ?? 0;
    final remoteVersion = remoteData['version'] as int? ?? 0;

    if (remoteVersion > localVersion) {
      return ConflictResolution.serverWins;
    } else if (localVersion > remoteVersion) {
      return ConflictResolution.clientWins;
    } else {
      // Same version: check last update time
      final localUpdated = DateTime.parse(localData['updatedAt'] ?? '');
      final remoteUpdated = DateTime.parse(remoteData['updatedAt'] ?? '');

      return remoteUpdated.isAfter(localUpdated)
          ? ConflictResolution.serverWins
          : ConflictResolution.clientWins;
    }
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  /// Retry a failed operation
  Future<void> _retryOperation(String operationId) async {
    try {
      final item = await _dbHelper.getSyncOutboxItem(operationId);
      if (item == null) return;

      if (item.retryCount < 3) {
        await _syncOutboxItemToFirestore(item);
        await _dbHelper.updateSyncOutboxItemStatus(
          item.id,
          'synced',
          DateTime.now(),
        );
        _failedOperationIds.remove(operationId);
      } else {
        // Max retries exceeded
        await _dbHelper.updateSyncOutboxItemStatus(
          item.id,
          'failed',
          null,
        );
        throw Exception('Max retries exceeded');
      }
    } catch (e) {
      print('Retry failed: $e');
      rethrow;
    }
  }

  /// Generate unique operation ID
  String _generateOperationId(String entityType, String entityId, String op) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$entityType-$entityId-$op-$timestamp';
  }

  /// Get Firestore collection name from entity type
  String _getFirestoreCollection(String entityType) {
    const mapping = {
      'evaluation_session': 'evaluation_sessions',
      'referral': 'referrals',
      'attendance_event': 'attendance_events',
      'notification': 'notifications',
      'consent_record': 'consent_records',
      'category': 'categories',
    };
    return mapping[entityType] ?? '${entityType}s';
  }

  /// Direct sync to Firestore (web only)
  Future<void> _syncDirectToFirestore(
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    final collection = _getFirestoreCollection(entityType);
    final docRef = _firestore.collection(collection).doc(entityId);

    switch (operation) {
      case 'create':
      case 'update':
        await docRef.set(payload, SetOptions(merge: true));
        break;
      case 'delete':
        await docRef.delete();
        break;
    }
  }

  /// Update sync status
  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    for (final listener in _statusListeners) {
      listener();
    }
  }

  /// Notify error listeners
  void _notifyError(String error) {
    for (final listener in _errorListeners) {
      listener(error);
    }
  }

  /// Cleanup on logout
  void dispose() {
    _statusListeners.clear();
    _errorListeners.clear();
  }
}
