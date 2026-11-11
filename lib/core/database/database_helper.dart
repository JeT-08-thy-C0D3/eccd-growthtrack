import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../shared/models/user_model.dart';
import '../../shared/models/child_model.dart';
import '../../shared/models/file_upload_model.dart';
import '../../shared/models/assessment_model.dart';
import '../../shared/models/canonical/canonical_entities.dart';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite (sqflite) is not supported on Web.');
    }
    if (_database != null) return _database!;
    _database = await _initDB('eccd_growthtrack.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 16,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE users ADD COLUMN terms_accepted_at TEXT');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE activity_submissions ADD COLUMN evidence_url TEXT',
      );
      await db.execute(
        'ALTER TABLE activity_submissions ADD COLUMN evidence_media_type TEXT',
      );
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE children ADD COLUMN parent_uid TEXT');
      await db.execute('ALTER TABLE children ADD COLUMN teacher_uid TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE children ADD COLUMN affix TEXT');
    }
    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE activities ADD COLUMN developmental_domain TEXT NOT NULL DEFAULT 'General Development'",
      );
    }
    if (oldVersion < 7) {
      await _createSyncTables(db);
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS remote_cache (
          collection_name TEXT NOT NULL,
          document_id TEXT,
          payload TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (collection_name, document_id)
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute(
        "ALTER TABLE children ADD COLUMN status TEXT NOT NULL DEFAULT 'active'",
      );
    }
    if (oldVersion < 10) {
      await db.execute(
        'ALTER TABLE activities ADD COLUMN evidence_required INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 11) {
      await db.execute('UPDATE activities SET evidence_required = 1');
    }
    if (oldVersion < 12) {
      await db.execute(
        'ALTER TABLE activities ADD COLUMN assigned_teacher_uid TEXT',
      );
      await db.execute('ALTER TABLE activities ADD COLUMN parent_uid TEXT');
      await db.execute('ALTER TABLE activities ADD COLUMN section TEXT');
    }
    if (oldVersion < 13) {
      await db.execute(
        'ALTER TABLE activity_submissions ADD COLUMN evidence_file_name TEXT',
      );
    }
    if (oldVersion < 14) {
      await db.execute(
        'ALTER TABLE activity_submissions ADD COLUMN teacher_uid TEXT',
      );
      await db.execute(
        'ALTER TABLE activity_submissions ADD COLUMN parent_uid TEXT',
      );
    }
    if (oldVersion < 15) {
      // Nullable RFID fields keep every existing child valid until a card is
      // explicitly verified. Attendance fields preserve old rows unchanged.
      await db.execute('ALTER TABLE children ADD COLUMN rfid_uid TEXT');
      await db.execute(
        'ALTER TABLE children ADD COLUMN rfid_verified INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE children ADD COLUMN rfid_linked_at TEXT');
      await db.execute(
        'ALTER TABLE attendance ADD COLUMN attendance_event_id TEXT',
      );
      await db.execute(
        "ALTER TABLE attendance ADD COLUMN attendance_method TEXT NOT NULL DEFAULT 'manual'",
      );
      await db.execute(
        'ALTER TABLE attendance ADD COLUMN event_timestamp_utc TEXT',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_children_rfid_uid ON children(rfid_uid) WHERE rfid_uid IS NOT NULL',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_event_id ON attendance(attendance_event_id) WHERE attendance_event_id IS NOT NULL',
      );
      // Legacy databases may already contain manual duplicate Present rows.
      // Keep those historical records readable; new saves still use the
      // repository check and stable event id if this compatibility index cannot
      // be installed.
      try {
        await db.execute(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_present_per_child_day ON attendance(child_id, attendance_date) WHERE status = 'Present'",
        );
      } on DatabaseException {
        // Do not make a migration destructive merely to add a new safeguard.
      }
    }
    if (oldVersion < 16) {
      await db.execute('ALTER TABLE referrals ADD COLUMN admin_guidance TEXT');
      await db.execute(
        'ALTER TABLE referrals ADD COLUMN admin_guidance_updated_at TEXT',
      );
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const textUniqueType = 'TEXT NOT NULL UNIQUE';
    const textNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE users (
        id $idType,
        uid $textType,
        name $textType,
        email $textType UNIQUE,
        password $textType,
        role $textType,
        status $textType,
        created_at $textType,
        updated_at $textType,
        is_synced $integerType,
        terms_accepted_at $textNullable,
        fcm_token $textNullable
      )
    ''');

    await db.execute('''
      CREATE TABLE children (
        id $idType,
        child_id $textUniqueType,
        first_name $textType,
        last_name $textType,
        affix $textNullable,
        birth_date $textType,
        age $integerType,
        gender $textType,
        address $textType,
        parent_name $textType,
        teacher_name $textType,
        parent_uid $textNullable,
        teacher_uid $textNullable,
        status $textType DEFAULT 'active',
        updated_at $textType,
        is_synced $integerType,
        rfid_uid $textNullable,
        rfid_verified INTEGER NOT NULL DEFAULT 0,
        rfid_linked_at $textNullable
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id $idType,
        child_id $textType,
        attendance_date $textType,
        attendance_time $textType,
        status $textType,
        updated_at $textType,
        is_synced $integerType,
        attendance_event_id $textNullable UNIQUE,
        attendance_method $textType DEFAULT 'manual',
        event_timestamp_utc $textNullable,
        FOREIGN KEY (child_id) REFERENCES children (child_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_children_rfid_uid ON children(rfid_uid) WHERE rfid_uid IS NOT NULL',
    );
    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_present_per_child_day ON attendance(child_id, attendance_date) WHERE status = 'Present'",
    );

    await db.execute('''
      CREATE TABLE evaluations (
        id $idType,
        child_id $textType,
        domain $textType,
        score $integerType,
        remarks $textType,
        evaluation_date $textType,
        updated_at $textType,
        is_synced $integerType,
        FOREIGN KEY (child_id) REFERENCES children (child_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE parent_feedback (
        id $idType,
        child_id $textType,
        parent_id $integerType,
        parent_observation $textType,
        assistance_level $textType,
        notes $textType,
        submission_date $textType,
        updated_at $textType,
        is_synced $integerType,
        FOREIGN KEY (child_id) REFERENCES children (child_id) ON DELETE CASCADE,
        FOREIGN KEY (parent_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE triangulations (
        id $idType,
        child_id $textType,
        teacher_assessment_summary $textType,
        parent_feedback_summary $textType,
        historical_record_summary $textType,
        triangulated_summary $textType,
        development_status $textType,
        generated_date $textType,
        updated_at $textType,
        is_synced $integerType,
        FOREIGN KEY (child_id) REFERENCES children (child_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE development_summaries (
        id $idType,
        child_id $textType,
        triangulation_id $integerType,
        development_summary $textType,
        strength_areas $textType,
        improvement_areas $textType,
        suggested_home_activities $textType,
        approval_status $textType,
        approved_by $textNullable,
        approved_date $textNullable,
        created_date $textType,
        updated_at $textType,
        is_synced $integerType,
        FOREIGN KEY (child_id) REFERENCES children (child_id) ON DELETE CASCADE,
        FOREIGN KEY (triangulation_id) REFERENCES triangulations (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE activities (
        id $idType,
        child_id $textType,
        activity_title $textType,
        developmental_domain $textType,
        instructions $textType,
        due_date $textType,
        assigned_by $textType,
        created_date $textType,
        status $textType,
        updated_at $textType,
        is_synced $integerType,
        max_score INTEGER DEFAULT 20,
        evidence_required INTEGER NOT NULL DEFAULT 1,
        assigned_teacher_uid $textNullable,
        parent_uid $textNullable,
        section $textNullable,
        FOREIGN KEY (child_id) REFERENCES children (child_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_submissions (
        id $idType,
        activity_id $integerType,
        child_id $textType,
        parent_note $textType,
        assistance_level $textType,
        submission_date $textType,
        teacher_review $textNullable,
        review_status $textType,
        updated_at $textType,
        is_synced $integerType,
        storage_placeholder $textNullable,
        evidence_url $textNullable,
        evidence_media_type $textNullable,
        evidence_file_name $textNullable,
        teacher_uid $textNullable,
        parent_uid $textNullable,
        score INTEGER,
        FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE,
        FOREIGN KEY (child_id) REFERENCES children (child_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE referrals (
        id $idType,
        child_id $textType,
        concern $textType,
        description $textType,
        referral_date $textType,
        follow_up_date $textType,
        status $textType,
        follow_up_notes $textType,
        admin_guidance $textNullable,
        admin_guidance_updated_at $textNullable,
        updated_at $textType,
        is_synced $integerType,
        FOREIGN KEY (child_id) REFERENCES children (child_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_logs (
        id $idType,
        user_id $textType,
        action $textType,
        module $textType,
        description $textType,
        timestamp $textType,
        is_synced $integerType
      )
    ''');

    await db.execute('''
      CREATE TABLE clarifications (
        id $idType,
        child_id $textType,
        parent_id $integerType,
        teacher_id $integerType,
        category $textNullable,
        message $textType,
        response $textNullable,
        status $textType,
        created_at $textType,
        updated_at $textType,
        is_synced $integerType,
        FOREIGN KEY (child_id) REFERENCES children (child_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE file_uploads (
        id $idType,
        file_id $textUniqueType,
        entity_id $textType,
        category $textType,
        local_path $textType,
        remote_url $textNullable,
        created_at $textType,
        is_synced $integerType
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id $idType,
        doc_id $textNullable,
        recipient_uid $textType,
        child_id $textType,
        child_name $textType,
        type $textType,
        title $textType,
        body $textType,
        reference_id $textNullable,
        is_read $integerType,
        created_at $textType,
        is_synced $integerType
      )
    ''');

    await _createSyncTables(db);
    await db.execute('''
      CREATE TABLE remote_cache (
        collection_name TEXT NOT NULL,
        document_id TEXT,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (collection_name, document_id)
      )
    ''');
  }

  Future<void> _createSyncTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        synced_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS retry_queue (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        next_retry_at TEXT
      )
    ''');
  }

  // --- Generic CRUD ---

  Future<int> insertRecord(String table, Map<String, dynamic> row) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert(
      table,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateRecord(
    String table,
    Map<String, dynamic> row,
    String idField,
  ) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update(
      table,
      row,
      where: '$idField = ?',
      whereArgs: [row[idField]],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String table) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query(table, where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markAsSynced(
    String table,
    String idField,
    dynamic idValue,
  ) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.update(
      table,
      {'is_synced': 1},
      where: '$idField = ?',
      whereArgs: [idValue],
    );
  }

  // --- Offline sync outbox and retry queue ---

  Future<int> getPendingSyncCount() async {
    if (kIsWeb) return 0;
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM sync_outbox WHERE status = 'pending'",
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> insertSyncOutboxItem(dynamic item) async {
    if (kIsWeb) return;
    final db = await database;
    final data = item.toMap() as Map<String, dynamic>;
    await db.insert('sync_outbox', {
      'id': item.id as String,
      'payload': jsonEncode(data),
      'status': item.status as String,
      'retry_count': item.retryCount as int,
      'synced_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SyncOutboxItem>> getPendingSyncOutboxItems() async {
    if (kIsWeb) return [];
    final db = await database;
    final rows = await db.query('sync_outbox', where: "status = 'pending'");
    return rows
        .map(
          (row) => SyncOutboxItem.fromMap(
            Map<String, dynamic>.from(
              jsonDecode(row['payload'] as String) as Map,
            ),
          ),
        )
        .toList();
  }

  Future<SyncOutboxItem?> getSyncOutboxItem(String id) async {
    if (kIsWeb) return null;
    final db = await database;
    final rows = await db.query(
      'sync_outbox',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return SyncOutboxItem.fromMap(
      Map<String, dynamic>.from(
        jsonDecode(rows.first['payload'] as String) as Map,
      ),
    );
  }

  Future<void> updateSyncOutboxItemStatus(
    String id,
    String status,
    DateTime? syncedAt,
  ) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      'sync_outbox',
      {'status': status, 'synced_at': syncedAt?.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementOutboxRetryCount(String id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_outbox SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> cacheRemoteData(
    String collection,
    Map<String, dynamic> data,
  ) async {
    if (kIsWeb) return;
    final db = await database;
    final id = (data['id'] ?? data['__id'])?.toString();
    await db.insert('remote_cache', {
      'collection_name': collection,
      'document_id': id,
      'payload': jsonEncode(data),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertRetryQueueItem(
    String id,
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic> payload,
    int retryCount,
    String status,
  ) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('retry_queue', {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'retry_count': retryCount,
      'status': status,
      'next_retry_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateRetryQueueItemStatus(
    String id,
    String status,
    DateTime? nextRetryAt,
  ) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      'retry_queue',
      {'status': status, 'next_retry_at': nextRetryAt?.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearRetryQueue() async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('retry_queue');
  }

  // --- User Operations ---

  Future<int> createUser(UserModel user) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<UserModel?> readUser(int id) async {
    if (kIsWeb) return null;
    final db = await instance.database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return UserModel.fromMap(maps.first);
    return null;
  }

  Future<List<UserModel>> readAllUsers() async {
    if (kIsWeb) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get(const GetOptions(source: Source.server));
      return snapshot.docs
          .map(
            (doc) => UserModel.fromMap({
              ...doc.data(),
              'uid': doc.data()['uid'] ?? doc.id,
            }),
          )
          .toList();
    }

    final db = await instance.database;
    final result = await db.query('users');
    if (result.isNotEmpty) {
      return result.map((json) => UserModel.fromMap(json)).toList();
    }

    // A new device has no SQLite profile cache yet. Load it once from the
    // cloud, then keep a local copy for the next read/offline use.
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get(const GetOptions(source: Source.server));
      final users = snapshot.docs
          .map(
            (doc) => UserModel.fromMap({
              ...doc.data(),
              'uid': doc.data()['uid'] ?? doc.id,
            }),
          )
          .toList();
      for (final user in users) {
        final row = user.toMap()
          ..remove('id')
          ..['is_synced'] = 1;
        await db.insert(
          'users',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return users;
    } catch (_) {
      return [];
    }
  }

  Future<int> updateUserFcmToken(String uid, String token) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update(
      'users',
      {'fcm_token': token},
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  Future<int> delete(String table, int id) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // --- Child Operations ---

  Future<int> insertChild(ChildModel child) async {
    final cloudData = child.toMap()
      ..remove('id')
      ..remove('is_synced');

    if (kIsWeb) {
      await FirebaseFirestore.instance
          .collection('children')
          .doc(child.childId)
          .set({
            ...cloudData,
            'server_updated_at': FieldValue.serverTimestamp(),
            'server_created_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      return 0;
    }

    final db = await instance.database;
    final localData = child.toMap()
      ..remove('id')
      ..['is_synced'] = 0;
    final id = await db.insert(
      'children',
      localData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Local write is already complete. A cloud failure intentionally leaves
    // is_synced at 0 so SyncService can upload it once connectivity returns.
    try {
      await FirebaseFirestore.instance
          .collection('children')
          .doc(child.childId)
          .set({
            ...cloudData,
            'server_updated_at': FieldValue.serverTimestamp(),
            'server_created_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await db.update(
        'children',
        {'is_synced': 1},
        where: 'child_id = ?',
        whereArgs: [child.childId],
      );
    } catch (_) {}

    return id;
  }

  Future<List<ChildModel>> getAllChildren({
    bool includeInactive = false,
  }) async {
    if (kIsWeb) {
      return _fetchChildrenFromCloud(includeInactive: includeInactive);
    }

    final db = await instance.database;
    final result = await db.query(
      'children',
      where: includeInactive ? null : 'status = ?',
      whereArgs: includeInactive ? null : ['active'],
      orderBy: 'last_name ASC',
    );
    if (result.isNotEmpty) {
      return result.map((json) => ChildModel.fromMap(json)).toList();
    }

    return _fetchChildrenFromCloud(
      cacheDatabase: db,
      includeInactive: includeInactive,
    );
  }

  Future<List<ChildModel>> readChildrenByParent(
    String parentUid, {
    bool allowCloudFallback = true,
    bool includeInactive = false,
  }) async {
    if (kIsWeb) {
      return _fetchChildrenForUser(
        parentUid,
        isParent: true,
        includeInactive: includeInactive,
      );
    }

    final db = await instance.database;
    final userMaps = await db.query(
      'users',
      where: 'uid = ?',
      whereArgs: [parentUid],
    );
    final userName = userMaps.isEmpty ? null : userMaps.first['name'] as String;
    final ownerWhere = userName == null
        ? 'parent_uid = ?'
        : 'parent_uid = ? OR (parent_uid IS NULL AND parent_name = ?)';
    final ownerArgs = userName == null ? [parentUid] : [parentUid, userName];
    final result = await db.query(
      'children',
      where: includeInactive ? ownerWhere : 'status = ? AND ($ownerWhere)',
      whereArgs: includeInactive ? ownerArgs : ['active', ...ownerArgs],
    );
    if (result.isNotEmpty) {
      return result.map((json) => ChildModel.fromMap(json)).toList();
    }
    if (!allowCloudFallback) return [];

    return _fetchChildrenForUser(
      parentUid,
      isParent: true,
      cacheDatabase: db,
      includeInactive: includeInactive,
    );
  }

  Future<List<ChildModel>> readChildrenByTeacher(
    String teacherUid, {
    bool allowCloudFallback = true,
    bool includeInactive = false,
  }) async {
    if (kIsWeb) {
      return _fetchChildrenForUser(
        teacherUid,
        isParent: false,
        includeInactive: includeInactive,
      );
    }

    final db = await instance.database;
    final userMaps = await db.query(
      'users',
      where: 'uid = ?',
      whereArgs: [teacherUid],
    );
    final teacherName = userMaps.isEmpty
        ? null
        : userMaps.first['name'] as String;
    final ownerWhere = teacherName == null
        ? 'teacher_uid = ?'
        : 'teacher_uid = ? OR (teacher_uid IS NULL AND teacher_name = ?)';
    final ownerArgs = teacherName == null
        ? [teacherUid]
        : [teacherUid, teacherName];
    final result = await db.query(
      'children',
      where: includeInactive ? ownerWhere : 'status = ? AND ($ownerWhere)',
      whereArgs: includeInactive ? ownerArgs : ['active', ...ownerArgs],
    );
    if (result.isNotEmpty) {
      return result.map((json) => ChildModel.fromMap(json)).toList();
    }
    if (!allowCloudFallback) return [];

    return _fetchChildrenForUser(
      teacherUid,
      isParent: false,
      cacheDatabase: db,
      includeInactive: includeInactive,
    );
  }

  /// Repairs legacy locally-cached child links created before teacher_uid was
  /// persisted. The name match is intentionally limited to the logged-in
  /// teacher, then the record is marked unsynced so normal sync can publish
  /// the corrected assignment.
  Future<int> repairLegacyTeacherAssignments({
    required String teacherUid,
    required String teacherName,
  }) async {
    if (kIsWeb || teacherUid.trim().isEmpty || teacherName.trim().isEmpty) {
      return 0;
    }
    final db = await instance.database;
    return db.update(
      'children',
      {
        'teacher_uid': teacherUid,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: "(teacher_uid IS NULL OR TRIM(teacher_uid) = '') AND LOWER(TRIM(teacher_name)) = ?",
      whereArgs: [teacherName.trim().toLowerCase()],
    );
  }

  Future<List<ChildModel>> _fetchChildrenFromCloud({
    Database? cacheDatabase,
    bool includeInactive = false,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('children')
          .get(const GetOptions(source: Source.server));
      final children = snapshot.docs
          .map(
            (doc) => ChildModel.fromMap({
              ...doc.data(),
              'child_id': doc.data()['child_id'] ?? doc.id,
            }),
          )
          .toList();
      if (cacheDatabase != null) await _cacheChildren(cacheDatabase, children);
      return includeInactive
          ? children
          : children.where((child) => child.isActive).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ChildModel>> _fetchChildrenForUser(
    String uid, {
    required bool isParent,
    Database? cacheDatabase,
    bool includeInactive = false,
  }) async {
    try {
      // Do not read the whole children collection here. Firestore correctly
      // rejects that query for teachers/parents because they may only read
      // their linked records.
      final assignmentField = isParent ? 'parent_uid' : 'teacher_uid';
      final snapshot = await FirebaseFirestore.instance
          .collection('children')
          .where(assignmentField, isEqualTo: uid)
          .get(const GetOptions(source: Source.server));
      final children = snapshot.docs
          .map(
            (doc) => ChildModel.fromMap({
              ...doc.data(),
              'child_id': doc.data()['child_id'] ?? doc.id,
            }),
          )
          .toList();
      if (cacheDatabase != null) await _cacheChildren(cacheDatabase, children);
      return includeInactive
          ? children
          : children.where((child) => child.isActive).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _cacheChildren(Database db, List<ChildModel> children) async {
    final batch = db.batch();
    for (final child in children) {
      final row = child.toMap()
        ..remove('id')
        ..['is_synced'] = 1;
      batch.insert(
        'children',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // --- Attendance ---

  Future<int> insertAttendance(Map<String, dynamic> attendance) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('attendance', attendance);
  }

  Future<List<Map<String, dynamic>>> getChildAttendanceHistory(
    String childId,
  ) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query(
      'attendance',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'attendance_date DESC',
    );
  }

  Future<Map<String, dynamic>?> getPresentAttendanceForSchoolDay(
    String childId,
    String schoolDate,
  ) async {
    if (kIsWeb) return null;
    final db = await instance.database;
    final rows = await db.query(
      'attendance',
      where: 'child_id = ? AND attendance_date = ? AND status = ?',
      whereArgs: [childId, schoolDate, 'Present'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getAttendanceByEventId(String eventId) async {
    if (kIsWeb) return null;
    final db = await instance.database;
    final rows = await db.query(
      'attendance',
      where: 'attendance_event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAttendanceSummaryByDate(
    String date,
  ) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT a.*, c.first_name, c.last_name
      FROM attendance a
      JOIN children c ON a.child_id = c.child_id
      WHERE a.attendance_date = ?
    ''',
      [date],
    );
  }

  // --- Evaluations ---

  Future<int> insertEvaluation(Map<String, dynamic> evaluation) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('evaluations', evaluation);
  }

  Future<int> createAssessment(AssessmentModel assessment) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('evaluations', assessment.toMap());
  }

  Future<List<Map<String, dynamic>>> getChildEvaluationHistory(
    String childId,
  ) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query(
      'evaluations',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'evaluation_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getLatestEvaluations(
    String childId,
  ) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT e1.* FROM evaluations e1
      WHERE e1.child_id = ? AND e1.evaluation_date = (
        SELECT MAX(e2.evaluation_date) FROM evaluations e2
        WHERE e2.child_id = e1.child_id AND e2.domain = e1.domain
      )
    ''',
      [childId],
    );
  }

  // --- Home Activities ---

  Future<List<Map<String, dynamic>>> getHomeActivitiesByTeacher(
    int teacherId,
  ) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final userMaps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [teacherId],
    );
    if (userMaps.isEmpty) return [];
    final teacherName = userMaps.first['name'] as String;
    return await db.query(
      'activities',
      where: 'assigned_by = ?',
      whereArgs: [teacherName],
    );
  }

  Future<int> createHomeActivity(
    int teacherId,
    int childLocalId,
    String title,
    String instructions, {
    int maxScore = 20,
    bool evidenceRequired = true,
  }) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    final teacherMaps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [teacherId],
    );
    final childMaps = await db.query(
      'children',
      where: 'id = ?',
      whereArgs: [childLocalId],
    );
    if (teacherMaps.isEmpty || childMaps.isEmpty) return 0;
    final teacherName = teacherMaps.first['name'] as String;
    final childId = childMaps.first['child_id'] as String;
    final now = DateTime.now().toIso8601String();
    return await db.insert('activities', {
      'child_id': childId,
      'activity_title': title,
      'instructions': instructions,
      'due_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'assigned_by': teacherName,
      'created_date': now,
      'status': 'Assigned',
      'updated_at': now,
      'is_synced': 0,
      'max_score': maxScore,
      'evidence_required': evidenceRequired ? 1 : 0,
    });
  }

  Future<List<Map<String, dynamic>>> getActivitiesByChild(
    String childId,
  ) async {
    if (kIsWeb) {
      return _fetchWebActivities(childId: childId);
    }
    final db = await instance.database;
    return await db.query(
      'activities',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'due_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllActivities() async {
    if (kIsWeb) {
      return _fetchWebActivities();
    }
    final db = await instance.database;
    return await db.query('activities', orderBy: 'due_date DESC');
  }

  /// Web activity queries include the logged-in user's owner field. Firestore
  /// rules can therefore prove that a teacher/parent can only receive records
  /// intended for them instead of rejecting a broad collection read.
  Future<List<Map<String, dynamic>>> _fetchWebActivities({
    String? childId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    final role = (profile.data()?['role'] as String? ?? '').toLowerCase();
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'activities',
    );
    if (childId != null) {
      query = query.where('child_id', isEqualTo: childId);
    }
    if (role == 'teacher') {
      query = query.where('assigned_teacher_uid', isEqualTo: user.uid);
    } else if (role == 'parent') {
      query = query.where('parent_uid', isEqualTo: user.uid);
    } else if (role != 'admin') {
      return [];
    }

    final snapshot = await query.get(const GetOptions(source: Source.server));
    final activities = snapshot.docs
        .map(
          (doc) => <String, dynamic>{
            ...doc.data(),
            'id': doc.data()['id'] ?? int.tryParse(doc.id),
          },
        )
        .toList();
    activities.sort(
      (a, b) => (b['due_date']?.toString() ?? '').compareTo(
        a['due_date']?.toString() ?? '',
      ),
    );
    return activities;
  }

  Future<int> updateActivityStatus(int id, String status) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update(
      'activities',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertActivitySubmission(Map<String, dynamic> submission) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('activity_submissions', submission);
  }

  Future<Map<String, dynamic>?> getSubmissionByActivity(int activityId) async {
    if (kIsWeb) return null;
    final db = await instance.database;
    final maps = await db.query(
      'activity_submissions',
      where: 'activity_id = ?',
      whereArgs: [activityId],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<int> updateActivitySubmissionEvidence(
    int submissionId, {
    required String evidenceUrl,
    required String evidenceMediaType,
    String? evidenceFileName,
  }) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return db.update(
      'activity_submissions',
      {
        'evidence_url': evidenceUrl,
        'evidence_media_type': evidenceMediaType,
        'evidence_file_name': evidenceFileName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [submissionId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllSubmissions() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT s.*, a.activity_title, a.max_score, c.first_name, c.last_name,
             c.parent_name
      FROM activity_submissions s
      JOIN activities a ON s.activity_id = a.id
      JOIN children c ON s.child_id = c.child_id
      ORDER BY s.submission_date DESC
    ''');
  }

  Future<int> updateSubmissionReview(
    int submissionId,
    String review,
    String status, {
    int? score,
  }) async {
    if (kIsWeb) return 0;
    final db = await instance.database;

    // Enforce the activity's score range at the data layer as well as in the
    // form. This prevents an invalid score from being saved by any caller.
    if (score != null) {
      final scoreLimit = await db.rawQuery(
        '''
        SELECT a.max_score
        FROM activity_submissions s
        INNER JOIN activities a ON a.id = s.activity_id
        WHERE s.id = ?
        LIMIT 1
        ''',
        [submissionId],
      );
      if (scoreLimit.isEmpty) {
        throw StateError('Activity submission was not found.');
      }
      final maxScore = (scoreLimit.first['max_score'] as num?)?.toInt() ?? 20;
      if (score < 0 || score > maxScore) {
        throw StateError('Score must be between 0 and $maxScore.');
      }
    }

    final updates = <String, dynamic>{
      'teacher_review': review,
      'review_status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (score != null) {
      updates['score'] = score;
    }
    return await db.update(
      'activity_submissions',
      updates,
      where: 'id = ?',
      whereArgs: [submissionId],
    );
  }

  // --- Feedback ---

  Future<int> insertFeedback(Map<String, dynamic> feedback) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('parent_feedback', feedback);
  }

  Future<List<Map<String, dynamic>>> getFeedbackByChild(String childId) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query(
      'parent_feedback',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'submission_date DESC',
    );
  }

  // --- Triangulations & Summaries ---

  Future<int> insertTriangulation(Map<String, dynamic> triangulation) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('triangulations', triangulation);
  }

  Future<List<Map<String, dynamic>>> getTriangulationHistory(
    String childId,
  ) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query(
      'triangulations',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'generated_date DESC',
    );
  }

  Future<int> insertDevelopmentSummary(Map<String, dynamic> summary) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('development_summaries', summary);
  }

  Future<List<Map<String, dynamic>>> getDevelopmentSummaryHistory(
    String childId,
  ) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query(
      'development_summaries',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'created_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getApprovedSummariesByChild(
    String childId,
  ) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query(
      'development_summaries',
      where: 'child_id = ? AND approval_status = ?',
      whereArgs: [childId, 'Approved'],
      orderBy: 'approved_date DESC',
    );
  }

  Future<Map<String, dynamic>?> getLatestApprovedSummary(String childId) async {
    if (kIsWeb) return null;
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'development_summaries',
      where: 'child_id = ? AND approval_status = ?',
      whereArgs: [childId, 'Approved'],
      orderBy: 'approved_date DESC',
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<int> updateDevelopmentSummaryStatus(
    int id,
    String status,
    String approvedBy,
    String approvedDate,
  ) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update(
      'development_summaries',
      {
        'approval_status': status,
        'approved_by': approvedBy,
        'approved_date': approvedDate,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Referrals ---

  Future<List<Map<String, dynamic>>> getReferralsByChild(String childId) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query(
      'referrals',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'referral_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllReferrals() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT r.*, c.first_name, c.last_name
      FROM referrals r
      JOIN children c ON r.child_id = c.child_id
      ORDER BY r.referral_date DESC
    ''');
  }

  // --- Notifications ---

  Future<int> insertNotification(Map<String, dynamic> notification) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('notifications', notification);
  }

  Future<List<Map<String, dynamic>>> getNotificationsByParent(
    String parentUid,
  ) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query(
      'notifications',
      where: 'recipient_uid = ?',
      whereArgs: [parentUid],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> markNotificationAsRead(int id) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAllNotificationsAsRead(String parentUid) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update(
      'notifications',
      {'is_read': 1},
      where: 'recipient_uid = ?',
      whereArgs: [parentUid],
    );
  }

  // --- Reports & Stats ---

  Future<Map<String, dynamic>> getDashboardStats(String today) async {
    if (kIsWeb) return {};
    final db = await instance.database;
    final totalChildren =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM children'),
        ) ??
        0;
    final totalTeachers =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users WHERE role = ?', [
            'teacher',
          ]),
        ) ??
        0;
    final totalParents =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users WHERE role = ?', [
            'parent',
          ]),
        ) ??
        0;
    final presentToday =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM attendance WHERE attendance_date = ? AND status = ?',
            [today, 'Present'],
          ),
        ) ??
        0;
    final absentToday =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM attendance WHERE attendance_date = ? AND status = ?',
            [today, 'Absent'],
          ),
        ) ??
        0;
    final completedEvaluations =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(DISTINCT child_id) FROM evaluations'),
        ) ??
        0;
    final pendingReferrals =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM referrals WHERE status = ?', [
            'Pending',
          ]),
        ) ??
        0;

    return {
      'total_children': totalChildren,
      'total_teachers': totalTeachers,
      'total_parents': totalParents,
      'present_today': presentToday,
      'absent_today': absentToday,
      'completed_evaluations': completedEvaluations,
      'pending_referrals': pendingReferrals,
    };
  }

  Future<List<Map<String, dynamic>>> getAttendanceReport() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.child_id, (c.first_name || ' ' || c.last_name) as child_name,
      SUM(CASE WHEN a.status = 'Present' THEN 1 ELSE 0 END) as present,
      SUM(CASE WHEN a.status = 'Absent' THEN 1 ELSE 0 END) as absent
      FROM children c LEFT JOIN attendance a ON c.child_id = a.child_id
      GROUP BY c.child_id
    ''');
  }

  Future<List<Map<String, dynamic>>> getEvaluationReport() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT e.*, (c.first_name || ' ' || c.last_name) as child_name
      FROM evaluations e JOIN children c ON e.child_id = c.child_id
    ''');
  }

  Future<List<Map<String, dynamic>>> getReferralReport() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT r.*, (c.first_name || ' ' || c.last_name) as child_name
      FROM referrals r JOIN children c ON r.child_id = c.child_id
    ''');
  }

  Future<List<Map<String, dynamic>>> getChildProgressReport() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT e.child_id, (c.first_name || ' ' || c.last_name) as child_name,
      e.domain, e.score as current_score
      FROM evaluations e JOIN children c ON e.child_id = c.child_id
    ''');
  }

  Future<Map<String, dynamic>> getChildProgressSummary(int childLocalId) async {
    if (kIsWeb) return {'assessments': [], 'attendance_rate': 0.0};
    final db = await instance.database;
    final childMaps = await db.query(
      'children',
      where: 'id = ?',
      whereArgs: [childLocalId],
    );
    if (childMaps.isEmpty) return {'assessments': [], 'attendance_rate': 0.0};
    final childId = childMaps.first['child_id'] as String;
    final assessmentMaps = await db.rawQuery(
      'SELECT domain, AVG(score) as avg_score FROM evaluations WHERE child_id = ? GROUP BY domain',
      [childId],
    );
    final total =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM attendance WHERE child_id = ?',
            [childId],
          ),
        ) ??
        0;
    final present =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM attendance WHERE child_id = ? AND status = ?',
            [childId, 'Present'],
          ),
        ) ??
        0;
    return {
      'assessments': assessmentMaps
          .map(
            (e) => {
              'domain': e['domain'],
              'avg_score': (e['avg_score'] as num?)?.toDouble() ?? 0.0,
            },
          )
          .toList(),
      'attendance_rate': total > 0 ? (present / total) * 100 : 0.0,
    };
  }

  // --- File Uploads ---

  Future<int> insertFileUpload(FileUploadModel fileUpload) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert(
      'file_uploads',
      fileUpload.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<FileUploadModel?> getFileUploadByFileId(String fileId) async {
    if (kIsWeb) return null;
    final db = await instance.database;
    final maps = await db.query(
      'file_uploads',
      where: 'file_id = ?',
      whereArgs: [fileId],
    );
    if (maps.isNotEmpty) return FileUploadModel.fromMap(maps.first);
    return null;
  }

  Future<List<FileUploadModel>> getUnsyncedFileUploads() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query(
      'file_uploads',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => FileUploadModel.fromMap(json)).toList();
  }

  Future<int> markFileUploadSynced(String fileId, String remoteUrl) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update(
      'file_uploads',
      {'remote_url': remoteUrl, 'is_synced': 1},
      where: 'file_id = ?',
      whereArgs: [fileId],
    );
  }

  Future close() async {
    if (kIsWeb) return;
    final db = await instance.database;
    db.close();
  }
}
