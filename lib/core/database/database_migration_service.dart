/// Database Migration Service
/// 
/// Manages SQLite schema versioning and migration.
/// Tracks schema versions and handles data transformations between versions.
library;

import 'package:sqflite/sqflite.dart';

class DatabaseMigration {
  final int version;
  final String name;
  final Future<void> Function(Database) onUpgrade;
  final Future<void> Function(Database) onDowngrade;

  DatabaseMigration({
    required this.version,
    required this.name,
    required this.onUpgrade,
    required this.onDowngrade,
  });
}

class DatabaseMigrationService {
  static final DatabaseMigrationService _instance =
      DatabaseMigrationService._init();

  final List<DatabaseMigration> _migrations = [];
  int _currentVersion = 0;

  DatabaseMigrationService._init();

  factory DatabaseMigrationService() => _instance;

  /// Register a migration
  void registerMigration(DatabaseMigration migration) {
    _migrations.add(migration);
    _migrations.sort((a, b) => a.version.compareTo(b.version));
    print('✓ Registered migration v${migration.version}: ${migration.name}');
  }

  /// Apply pending migrations
  Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    print('📦 Migrating database: v$oldVersion → v$newVersion');

    if (oldVersion < newVersion) {
      // Upgrade
      for (final migration in _migrations) {
        if (migration.version > oldVersion && migration.version <= newVersion) {
          try {
            print('  ↑ Applying v${migration.version}: ${migration.name}');
            await migration.onUpgrade(db);
            print('  ✓ v${migration.version} complete');
          } catch (e) {
            print('  ✗ v${migration.version} failed: $e');
            rethrow;
          }
        }
      }
    } else if (oldVersion > newVersion) {
      // Downgrade (rarely used)
      for (final migration in _migrations.reversed) {
        if (migration.version <= oldVersion && migration.version > newVersion) {
          try {
            print('  ↓ Reverting v${migration.version}: ${migration.name}');
            await migration.onDowngrade(db);
            print('  ✓ v${migration.version} reverted');
          } catch (e) {
            print('  ✗ v${migration.version} revert failed: $e');
            rethrow;
          }
        }
      }
    }

    _currentVersion = newVersion;
    print('✓ Migration complete: now at v$_currentVersion');
  }

  /// Get current schema version
  int get currentVersion => _currentVersion;
}

// ============================================================================
// PREDEFINED MIGRATIONS
// ============================================================================

/// Migration v1: Initial schema (baseline for legacy system)
DatabaseMigration createMigrationV1() {
  return DatabaseMigration(
    version: 1,
    name: 'Initial schema setup',
    onUpgrade: (db) async {
      // Create tables for outbox/inbox sync
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_outbox (
          id TEXT PRIMARY KEY,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          operation_id TEXT NOT NULL UNIQUE,
          tombstone INTEGER DEFAULT 0,
          retry_count INTEGER DEFAULT 0,
          status TEXT DEFAULT 'pending',
          created_at DATETIME NOT NULL,
          synced_at DATETIME
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_inbox (
          id TEXT PRIMARY KEY,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          remote_version INTEGER,
          local_version INTEGER,
          conflict_status TEXT DEFAULT 'none',
          resolved_at DATETIME,
          created_at DATETIME NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS retry_queue (
          id TEXT PRIMARY KEY,
          operation_id TEXT NOT NULL UNIQUE,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0,
          status TEXT DEFAULT 'pending',
          created_at DATETIME NOT NULL,
          last_attempt_at DATETIME,
          next_retry_at DATETIME
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS schema_version (
          id INTEGER PRIMARY KEY,
          version INTEGER NOT NULL,
          applied_at DATETIME NOT NULL
        )
      ''');

      print('  ✓ Created sync tables');
    },
    onDowngrade: (db) async {
      await db.execute('DROP TABLE IF EXISTS sync_outbox');
      await db.execute('DROP TABLE IF EXISTS sync_inbox');
      await db.execute('DROP TABLE IF EXISTS retry_queue');
      await db.execute('DROP TABLE IF EXISTS schema_version');
      print('  ✓ Dropped sync tables');
    },
  );
}

/// Migration v2: Add cache expiration tracking
DatabaseMigration createMigrationV2() {
  return DatabaseMigration(
    version: 2,
    name: 'Add cache expiration and encryption metadata',
    onUpgrade: (db) async {
      // Add columns to sync_outbox
      await db.execute('''
        ALTER TABLE sync_outbox 
        ADD COLUMN cache_expires_at DATETIME
      ''');

      await db.execute('''
        ALTER TABLE sync_outbox 
        ADD COLUMN is_encrypted INTEGER DEFAULT 0
      ''');

      // Create cache expiration index
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sync_outbox_expires 
        ON sync_outbox(cache_expires_at)
      ''');

      // Create audit table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_audit_log (
          id TEXT PRIMARY KEY,
          operation_id TEXT,
          action TEXT NOT NULL,
          timestamp DATETIME NOT NULL,
          details TEXT
        )
      ''');

      print('  ✓ Added cache expiration and encryption tracking');
    },
    onDowngrade: (db) async {
      // Downgrade is complex for ALTER TABLE; typically recreate
      print('  ⚠️ Downgrade to v1 requires full data migration (not implemented)');
    },
  );
}

/// Migration v3: Add conflict resolution metadata
DatabaseMigration createMigrationV3() {
  return DatabaseMigration(
    version: 3,
    name: 'Add conflict resolution strategy tracking',
    onUpgrade: (db) async {
      await db.execute('''
        ALTER TABLE sync_inbox 
        ADD COLUMN resolution_strategy TEXT DEFAULT 'server_wins'
      ''');

      await db.execute('''
        ALTER TABLE sync_inbox 
        ADD COLUMN resolved_by_user_id TEXT
      ''');

      await db.execute('''
        ALTER TABLE sync_outbox 
        ADD COLUMN conflict_detected INTEGER DEFAULT 0
      ''');

      print('  ✓ Added conflict resolution metadata');
    },
    onDowngrade: (db) async {
      print('  ⚠️ Downgrade not implemented for v3');
    },
  );
}

/// Migration v4: Add cache policies table
DatabaseMigration createMigrationV4() {
  return DatabaseMigration(
    version: 4,
    name: 'Add cache policy and lifecycle management',
    onUpgrade: (db) async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cache_policies (
          id TEXT PRIMARY KEY,
          entity_type TEXT NOT NULL UNIQUE,
          ttl_seconds INTEGER NOT NULL,
          max_size_bytes INTEGER,
          eviction_policy TEXT DEFAULT 'lru',
          created_at DATETIME NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS cache_lifecycle (
          id TEXT PRIMARY KEY,
          entity_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          cached_at DATETIME NOT NULL,
          accessed_at DATETIME NOT NULL,
          expires_at DATETIME NOT NULL,
          size_bytes INTEGER,
          hit_count INTEGER DEFAULT 0
        )
      ''');

      // Create indexes for lifecycle queries
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_cache_lifecycle_expires 
        ON cache_lifecycle(expires_at)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_cache_lifecycle_entity 
        ON cache_lifecycle(entity_type, entity_id)
      ''');

      print('  ✓ Added cache policy and lifecycle tables');
    },
    onDowngrade: (db) async {
      await db.execute('DROP TABLE IF EXISTS cache_policies');
      await db.execute('DROP TABLE IF EXISTS cache_lifecycle');
      print('  ✓ Removed cache policy tables');
    },
  );
}
