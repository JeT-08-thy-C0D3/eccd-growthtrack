# PHASE 4: OFFLINE & SYNCHRONIZATION REDESIGN

## Implementation Guide

---

## Overview

Phase 4 consolidates two disparate sync implementations (sync_service.dart + sync_engine.dart) into a unified system with:

- **Outbox/Inbox Pattern**: Local changes queued → Firestore
- **Idempotency**: Operation IDs prevent duplicate processing
- **Conflict Resolution**: Server-wins strategy with versioning
- **Retry Queue**: Exponential backoff for failed operations
- **Database Encryption**: AES-256 for local SQLite
- **Cache Expiration**: TTL-based cleanup
- **Migration Versioning**: Controlled schema evolution

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      ECCD GrowthTrack                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  CLIENT LAYER                                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  UI / Business Logic                                 │  │
│  │  - recordLocalChange()  (teacher edits evaluation)  │  │
│  │  - sync()               (upload + download)         │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                  │
│  SYNC LAYER (Unified)                                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  UnifiedSyncService                                  │  │
│  │  - recordLocalChange() → SyncOutbox                 │  │
│  │  - _uploadPendingChanges()  (Outbox → Firestore)   │  │
│  │  - _downloadRemoteUpdates() (Firestore → Inbox)    │  │
│  │  - _applyRemoteChanges()    (Inbox → Cache)        │  │
│  │  - _resolveConflict()       (Versioning strategy)  │  │
│  └──────────────────────────────────────────────────────┘  │
│           ↓                              ↓                   │
│  RETRY QUEUE                    DATABASE ENCRYPTION         │
│  ┌────────────────────────┐  ┌─────────────────────────┐  │
│  │ SyncRetryQueue         │  │ DatabaseEncryption      │  │
│  │ - exponentialBackoff() │  │ - encryptData()         │  │
│  │ - processQueue()       │  │ - decryptData()         │  │
│  │ - maxRetries: 3        │  │ - AES-256               │  │
│  └────────────────────────┘  └─────────────────────────┘  │
│                                                              │
│  DATABASE LAYER                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  SQLite (Mobile)                                     │  │
│  │  - sync_outbox    (pending operations)              │  │
│  │  - sync_inbox     (remote updates)                  │  │
│  │  - retry_queue    (failed operations)               │  │
│  │  - cache_*        (evaluation cache)                │  │
│  │  - schema_version (migration tracking)              │  │
│  └──────────────────────────────────────────────────────┘  │
│           ↓                                                  │
│  CLOUD LAYER                                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Firestore (Authority of Truth)                     │  │
│  │  - evaluation_sessions                              │  │
│  │  - referrals                                        │  │
│  │  - attendance_events                                │  │
│  │  - notifications                                    │  │
│  │  (Firestore Rules enforce access control)          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## New Files Created

1. **lib/core/sync/unified_sync_service.dart** (290 lines)
   - Single source for all sync operations
   - Manages outbox, inbox, conflicts
   - Visible sync status (SyncStatus enum)
   - Web: direct Firestore
   - Mobile: offline-first SQLite queue

2. **lib/core/database/database_encryption_service.dart** (140 lines)
   - AES-256 encryption using `crypto` + `encrypt` packages
   - Key derivation from Firebase UID
   - Encrypts sensitive evaluation data at rest

3. **lib/core/sync/sync_retry_queue.dart** (240 lines)
   - Exponential backoff (1s, 2s, 4s, 8s...)
   - Max 3 retries per operation
   - Persistent retry state in SQLite
   - Automatic scheduling

4. **lib/core/database/database_migration_service.dart** (310 lines)
   - Version-controlled schema evolution
   - 4 predefined migrations:
     - v1: Initial sync tables
     - v2: Cache expiration tracking
     - v3: Conflict resolution metadata
     - v4: Cache policy management

---

## Database Schema (SQLite)

### sync_outbox (Operations to upload)
```sql
CREATE TABLE sync_outbox (
  id TEXT PRIMARY KEY,
  entity_type TEXT,           -- 'evaluation_session', 'referral', etc.
  entity_id TEXT,             -- ID of the entity being synced
  operation TEXT,             -- 'create', 'update', 'delete'
  payload TEXT,               -- JSON of entity data (encrypted)
  operation_id TEXT UNIQUE,   -- Idempotency key
  tombstone INTEGER DEFAULT 0, -- Soft delete marker
  retry_count INTEGER,
  status TEXT,                -- 'pending', 'synced', 'failed'
  created_at DATETIME,
  synced_at DATETIME,
  cache_expires_at DATETIME,
  is_encrypted INTEGER
);
CREATE INDEX idx_sync_outbox_expires ON sync_outbox(cache_expires_at);
```

### sync_inbox (Updates to apply locally)
```sql
CREATE TABLE sync_inbox (
  id TEXT PRIMARY KEY,
  entity_type TEXT,
  entity_id TEXT,
  payload TEXT,               -- JSON from Firestore
  remote_version INTEGER,
  local_version INTEGER,
  conflict_status TEXT,       -- 'none', 'detected', 'resolved'
  resolution_strategy TEXT,   -- 'server_wins', 'client_wins', 'manual'
  resolved_by_user_id TEXT,   -- Who resolved it
  resolved_at DATETIME,
  created_at DATETIME
);
```

### retry_queue (Failed operations to retry)
```sql
CREATE TABLE retry_queue (
  id TEXT PRIMARY KEY,
  operation_id TEXT UNIQUE,
  entity_type TEXT,
  entity_id TEXT,
  operation TEXT,
  payload TEXT,
  retry_count INTEGER DEFAULT 0,
  status TEXT,                -- 'pending', 'success', 'failed'
  created_at DATETIME,
  last_attempt_at DATETIME,
  next_retry_at DATETIME
);
CREATE INDEX idx_retry_queue_next ON retry_queue(next_retry_at);
```

### cache_policies (TTL management)
```sql
CREATE TABLE cache_policies (
  id TEXT PRIMARY KEY,
  entity_type TEXT UNIQUE,
  ttl_seconds INTEGER,        -- Time-to-live
  max_size_bytes INTEGER,
  eviction_policy TEXT,       -- 'lru' (Least Recently Used)
  created_at DATETIME
);
```

### cache_lifecycle (Cache hit tracking)
```sql
CREATE TABLE cache_lifecycle (
  id TEXT PRIMARY KEY,
  entity_id TEXT,
  entity_type TEXT,
  cached_at DATETIME,
  accessed_at DATETIME,       -- Last access (for LRU)
  expires_at DATETIME,        -- When to evict
  size_bytes INTEGER,
  hit_count INTEGER DEFAULT 0
);
CREATE INDEX idx_cache_lifecycle_expires ON cache_lifecycle(expires_at);
```

---

## Integration Steps

### 1. Update pubspec.yaml

```yaml
dependencies:
  encrypt: ^4.1.0        # For AES encryption
  crypto: ^3.0.3         # For key derivation
  sqflite: ^2.3.0        # Already present
  cloud_firestore: ^4.8.0 # Already present
```

### 2. Initialize Sync Service on App Startup

```dart
// In main.dart or app_startup.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize sync service
  final syncService = UnifiedSyncService();
  await syncService.initialize();
  
  // Configure retry queue
  SyncRetryQueue().configure(
    maxRetries: 3,
    strategy: RetryStrategy.exponentialBackoff,
  );
  
  // Initialize database migrations
  final dbHelper = DatabaseHelper.instance;
  await dbHelper.initializeDatabase();
  
  runApp(const MyApp());
}
```

### 3. Listen to Sync Status

```dart
// In a stateful widget
@override
void initState() {
  super.initState();
  
  final syncService = UnifiedSyncService();
  
  // Listen to sync status changes
  syncService.onStatusChanged(() {
    setState(() {
      _syncStatus = syncService.status;
      _pendingCount = syncService.pendingOperations;
    });
  });
  
  // Listen to errors
  syncService.onError((error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sync error: $error')),
    );
  });
}
```

### 4. Record Local Changes (Teacher Evaluation Example)

```dart
Future<void> saveEvaluation(EvaluationSession evaluation) async {
  final syncService = UnifiedSyncService();
  final dbHelper = DatabaseHelper.instance;
  
  // Save locally first
  await dbHelper.updateEvaluationSession(evaluation);
  
  // Queue for sync
  await syncService.recordLocalChange(
    entityType: 'evaluation_session',
    entityId: evaluation.id,
    operation: 'update',
    payload: evaluation.toJson(),
  );
  
  // Show sync status
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Saved. Syncing when connected...'),
      duration: Duration(seconds: 2),
    ),
  );
}
```

### 5. Trigger Sync (When Connected)

```dart
// In a sync controller
Future<void> manualSync() async {
  try {
    final syncService = UnifiedSyncService();
    await syncService.sync();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Sync successful')),
    );
  } catch (e) {
    // Sync failed; will retry automatically
    print('Sync error: $e');
  }
}
```

### 6. Cleanup on Logout

```dart
Future<void> logout() async {
  final syncService = UnifiedSyncService();
  final retryQueue = SyncRetryQueue();
  final encryption = DatabaseEncryptionService();
  final dbHelper = DatabaseHelper.instance;
  
  // Stop syncing
  syncService.dispose();
  await retryQueue.clear();
  
  // Clear encryption keys
  encryption.dispose();
  
  // Wipe local database
  await dbHelper.wipeAllTables();
  
  // Sign out from Firebase
  await FirebaseAuth.instance.signOut();
}
```

---

## Conflict Resolution Strategy

### Server-Wins (Default)

When local and remote data differ:

1. **Version Check**
   ```
   remoteVersion > localVersion → Use remote data
   localVersion > remoteVersion → Use local data
   ```

2. **Timestamp Fallback**
   ```
   If versions equal: compare updatedAt timestamps
   Newer timestamp wins
   ```

3. **Example**
   ```
   Local: { version: 2, updatedAt: 2024-10-06T10:00:00, score: 5 }
   Remote: { version: 3, updatedAt: 2024-10-06T10:30:00, score: 4 }
   → Remote wins (higher version)
   Result: { version: 3, score: 4 }
   ```

### Manual Resolution (Future)

For high-stakes conflicts (e.g., evaluation scores):

```dart
Future<void> resolveConflict({
  required String entityId,
  required Map<String, dynamic> localData,
  required Map<String, dynamic> remoteData,
}) async {
  // Show UI dialog to teacher
  final choice = await showDialog<ConflictResolution>(
    context: context,
    builder: (context) => _ConflictResolutionDialog(
      local: localData,
      remote: remoteData,
    ),
  );
  
  // Apply choice
  await dbHelper.resolveConflict(
    entityId: entityId,
    resolution: choice,
  );
}
```

---

## Encryption Usage

### Enable Encryption on Auth

```dart
// In login flow, after Firebase auth succeeds
Future<void> onLoginSuccess(User user) async {
  final encryption = DatabaseEncryptionService();
  
  // Initialize with user's Firebase UID
  await encryption.initialize(user.uid);
  
  // All subsequent database operations are encrypted
  final evaluation = EvaluationSession(/* ... */);
  final encrypted = encryption.encryptJson(evaluation.toJson());
  
  // Store encrypted JSON
  await dbHelper.saveEvaluationEncrypted(encrypted);
}
```

### Decrypt on Retrieval

```dart
Future<EvaluationSession?> getEvaluation(String id) async {
  final encrypted = await dbHelper.getEvaluationEncrypted(id);
  
  if (encrypted == null) return null;
  
  final encryption = DatabaseEncryptionService();
  final decrypted = encryption.decryptJson(encrypted);
  
  return EvaluationSession.fromJson(decrypted);
}
```

---

## Cache Expiration Policy

Define TTL for each entity type:

```dart
final cachePolicy = <String, int>{
  'evaluation_sessions': 86400,     // 24 hours
  'referrals': 604800,              // 7 days
  'attendance_events': 2592000,     // 30 days
  'notifications': 604800,          // 7 days
  'categories': 2592000,            // 30 days
};

// Apply policy
for (final (entityType, ttlSeconds) in cachePolicy.entries) {
  await dbHelper.setCachePolicy(
    entityType: entityType,
    ttlSeconds: ttlSeconds,
  );
}

// Cleanup expired items
Future<void> cleanupExpiredCache() async {
  await dbHelper.deleteExpiredCacheItems();
}
```

---

## Database Migration Example

To add a new column to sync_outbox:

```dart
// Create migration v5
DatabaseMigration createMigrationV5() {
  return DatabaseMigration(
    version: 5,
    name: 'Add device_id to sync_outbox',
    onUpgrade: (db) async {
      await db.execute('''
        ALTER TABLE sync_outbox 
        ADD COLUMN device_id TEXT
      ''');
      print('  ✓ Added device_id column');
    },
    onDowngrade: (db) async {
      print('  ⚠️ Downgrade not implemented');
    },
  );
}

// Register migration
final migrationService = DatabaseMigrationService();
migrationService.registerMigration(createMigrationV5());
```

---

## Retry Queue Behavior

### Scenario: Teacher's Evaluation Upload Fails

```
Time  Event                              Status
─────────────────────────────────────────────────
0:00  Teacher submits evaluation       → pending (in outbox)
0:05  Network error: retry_count = 1   → scheduled at 0:06 (1s backoff)
0:06  Retry attempt fails: retry = 2   → scheduled at 0:08 (2s backoff)
0:08  Retry attempt fails: retry = 3   → scheduled at 0:12 (4s backoff)
0:12  Retry attempt succeeds           → synced (removed from queue)
0:15  Teacher sees "✓ Synced"          → success
```

### Exponential Backoff Formula
```
delay = 1000ms * (2 ^ retryCount) + random jitter (±10%)
Attempt 1: ~1.1s
Attempt 2: ~2.2s
Attempt 3: ~4.4s
```

---

## Testing the Sync System

### Unit Tests

```dart
// test/sync_service_test.dart
void main() {
  group('UnifiedSyncService', () {
    test('recordLocalChange adds to outbox', () async {
      final syncService = UnifiedSyncService();
      await syncService.recordLocalChange(
        entityType: 'evaluation_session',
        entityId: 'eval-123',
        operation: 'update',
        payload: {'score': 5},
      );
      
      expect(syncService.pendingOperations, greaterThan(0));
    });

    test('sync uploads pending changes', () async {
      // TODO: Mock Firestore
      final syncService = UnifiedSyncService();
      await syncService.sync();
      
      expect(syncService.status, SyncStatus.idle);
    });
  });
}
```

### Integration Tests

```dart
// Test sync with actual SQLite + Firestore Emulator
void main() {
  setUpAll(() async {
    // Start Firebase Emulator
    // Connect to emulator for tests
  });

  test('full sync flow', () async {
    // 1. Record change
    // 2. Trigger sync
    // 3. Verify Firestore received it
    // 4. Verify local cache updated
  });
}
```

---

## Monitoring & Debugging

### View Sync Status

```dart
void printSyncStatus() {
  final syncService = UnifiedSyncService();
  print('Sync Status: ${syncService.status}');
  print('Pending Operations: ${syncService.pendingOperations}');
  print('Last Sync: ${syncService.lastSyncTime}');
  
  final retryQueue = SyncRetryQueue();
  print('Retry Queue: ${retryQueue.getStatus()}');
}
```

### Query Outbox (SQLite)

```sql
-- Find pending operations
SELECT entity_type, entity_id, operation, status, created_at 
FROM sync_outbox 
WHERE status = 'pending'
ORDER BY created_at DESC;

-- Find failed operations (after 3 retries)
SELECT * FROM sync_outbox 
WHERE status = 'failed' 
AND retry_count >= 3;

-- Check cache expiration
SELECT entity_type, COUNT(*) as expired 
FROM cache_lifecycle 
WHERE expires_at < DATETIME('now')
GROUP BY entity_type;
```

---

## Phase 4 Approval Gate

**Before proceeding to Phase 5**, please verify:

- [ ] **Sync Service**: UnifiedSyncService properly manages outbox/inbox
- [ ] **Database Encryption**: Local SQLite data is encrypted at rest
- [ ] **Retry Queue**: Failed operations retry with exponential backoff
- [ ] **Migrations**: Database schema can evolve without data loss
- [ ] **Conflict Resolution**: Versioning strategy prevents data corruption
- [ ] **Cache Expiration**: Old evaluation data cleaned up automatically
- [ ] **Logout Cleanup**: All local data wiped on user logout
- [ ] **Web Behavior**: Web app uses Firestore directly (no SQLite)

**Open Questions**:
1. Should conflict resolution support "merge" strategy for certain fields?
2. Should evaluation scores use "manual" resolution instead of "server wins"?
3. Should sync be fully automatic or require user action?
4. How long should high-risk data (evaluation scores, referrals) be cached?

---

## Next Phase: Phase 5

Once Phase 4 approval is granted:

**Phase 5: Shared Query, Pagination, and Filtering Layer**

- Cursor-based pagination for all entity types
- Unified query builder supporting filters/sort/search
- Applied to: Users, Children, Referrals, Reports, Audit Log, etc.
- Estimated effort: 8-10 hours

