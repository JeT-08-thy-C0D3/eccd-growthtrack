import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/child_model.dart';
import '../../shared/models/file_upload_model.dart';
import '../../shared/models/assessment_model.dart';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) throw UnsupportedError('SQLite (sqflite) is not supported on Web.');
    if (_database != null) return _database!;
    _database = await _initDB('eccd_growthtrack.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE users ADD COLUMN terms_accepted_at TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE activity_submissions ADD COLUMN evidence_url TEXT');
      await db.execute('ALTER TABLE activity_submissions ADD COLUMN evidence_media_type TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE children ADD COLUMN parent_uid TEXT');
      await db.execute('ALTER TABLE children ADD COLUMN teacher_uid TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE children ADD COLUMN affix TEXT');
    }
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE activities ADD COLUMN developmental_domain TEXT NOT NULL DEFAULT 'General Development'");
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
        updated_at $textType,
        is_synced $integerType
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
        FOREIGN KEY (child_id) REFERENCES children (child_id) ON DELETE CASCADE
      )
    ''');

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
  }

  // --- Generic CRUD ---

  Future<int> insertRecord(String table, Map<String, dynamic> row) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateRecord(String table, Map<String, dynamic> row, String idField) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update(table, row, where: '$idField = ?', whereArgs: [row[idField]]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String table) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query(table, where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markAsSynced(String table, String idField, dynamic idValue) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.update(table, {'is_synced': 1}, where: '$idField = ?', whereArgs: [idValue]);
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
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('users');
    return result.map((json) => UserModel.fromMap(json)).toList();
  }

  Future<int> updateUserFcmToken(String uid, String token) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update('users', {'fcm_token': token}, where: 'uid = ?', whereArgs: [uid]);
  }

  Future<int> delete(String table, int id) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // --- Child Operations ---

  Future<int> insertChild(ChildModel child) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('children', child.toMap());
  }

  Future<List<ChildModel>> getAllChildren() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('children', orderBy: 'last_name ASC');
    return result.map((json) => ChildModel.fromMap(json)).toList();
  }

  Future<List<ChildModel>> readChildrenByParent(String parentUid) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final userMaps = await db.query('users', where: 'uid = ?', whereArgs: [parentUid]);
    if (userMaps.isEmpty) return [];
    final userName = userMaps.first['name'] as String;
    final result = await db.query(
      'children',
      where: 'parent_uid = ? OR (parent_uid IS NULL AND parent_name = ?)',
      whereArgs: [parentUid, userName],
    );
    return result.map((json) => ChildModel.fromMap(json)).toList();
  }

  Future<List<ChildModel>> readChildrenByTeacher(String teacherUid) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final userMaps = await db.query('users', where: 'uid = ?', whereArgs: [teacherUid]);
    if (userMaps.isEmpty) return [];
    final teacherName = userMaps.first['name'] as String;
    final result = await db.query(
      'children',
      where: 'teacher_uid = ? OR (teacher_uid IS NULL AND teacher_name = ?)',
      whereArgs: [teacherUid, teacherName],
    );
    return result.map((json) => ChildModel.fromMap(json)).toList();
  }

  // --- Attendance ---

  Future<int> insertAttendance(Map<String, dynamic> attendance) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('attendance', attendance);
  }

  Future<List<Map<String, dynamic>>> getChildAttendanceHistory(String childId) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query('attendance', where: 'child_id = ?', whereArgs: [childId], orderBy: 'attendance_date DESC');
  }

  Future<List<Map<String, dynamic>>> getAttendanceSummaryByDate(String date) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT a.*, c.first_name, c.last_name
      FROM attendance a
      JOIN children c ON a.child_id = c.child_id
      WHERE a.attendance_date = ?
    ''', [date]);
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

  Future<List<Map<String, dynamic>>> getChildEvaluationHistory(String childId) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query('evaluations', where: 'child_id = ?', whereArgs: [childId], orderBy: 'evaluation_date DESC');
  }

  Future<List<Map<String, dynamic>>> getLatestEvaluations(String childId) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT e1.* FROM evaluations e1
      WHERE e1.child_id = ? AND e1.evaluation_date = (
        SELECT MAX(e2.evaluation_date) FROM evaluations e2
        WHERE e2.child_id = e1.child_id AND e2.domain = e1.domain
      )
    ''', [childId]);
  }

  // --- Home Activities ---

  Future<List<Map<String, dynamic>>> getHomeActivitiesByTeacher(int teacherId) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final userMaps = await db.query('users', where: 'id = ?', whereArgs: [teacherId]);
    if (userMaps.isEmpty) return [];
    final teacherName = userMaps.first['name'] as String;
    return await db.query('activities', where: 'assigned_by = ?', whereArgs: [teacherName]);
  }

  Future<int> createHomeActivity(int teacherId, int childLocalId, String title, String instructions, {int maxScore = 20}) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    final teacherMaps = await db.query('users', where: 'id = ?', whereArgs: [teacherId]);
    final childMaps = await db.query('children', where: 'id = ?', whereArgs: [childLocalId]);
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
    });
  }

  Future<List<Map<String, dynamic>>> getActivitiesByChild(String childId) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query('activities', where: 'child_id = ?', whereArgs: [childId], orderBy: 'due_date DESC');
  }

  Future<List<Map<String, dynamic>>> getAllActivities() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query('activities', orderBy: 'due_date DESC');
  }

  Future<int> updateActivityStatus(int id, String status) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update('activities', {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertActivitySubmission(Map<String, dynamic> submission) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('activity_submissions', submission);
  }

  Future<Map<String, dynamic>?> getSubmissionByActivity(int activityId) async {
    if (kIsWeb) return null;
    final db = await instance.database;
    final maps = await db.query('activity_submissions', where: 'activity_id = ?', whereArgs: [activityId]);
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<int> updateActivitySubmissionEvidence(
    int submissionId, {
    required String evidenceUrl,
    required String evidenceMediaType,
  }) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return db.update(
      'activity_submissions',
      {
        'evidence_url': evidenceUrl,
        'evidence_media_type': evidenceMediaType,
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
      SELECT s.*, a.activity_title, a.max_score, c.first_name, c.last_name
      FROM activity_submissions s
      JOIN activities a ON s.activity_id = a.id
      JOIN children c ON s.child_id = c.child_id
      ORDER BY s.submission_date DESC
    ''');
  }

  Future<int> updateSubmissionReview(int submissionId, String review, String status, {int? score}) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    final updates = <String, dynamic>{
      'teacher_review': review,
      'review_status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (score != null) {
      updates['score'] = score;
    }
    return await db.update('activity_submissions', updates, where: 'id = ?', whereArgs: [submissionId]);
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
    return await db.query('parent_feedback', where: 'child_id = ?', whereArgs: [childId], orderBy: 'submission_date DESC');
  }

  // --- Triangulations & Summaries ---

  Future<int> insertTriangulation(Map<String, dynamic> triangulation) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('triangulations', triangulation);
  }

  Future<List<Map<String, dynamic>>> getTriangulationHistory(String childId) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query('triangulations', where: 'child_id = ?', whereArgs: [childId], orderBy: 'generated_date DESC');
  }

  Future<int> insertDevelopmentSummary(Map<String, dynamic> summary) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('development_summaries', summary);
  }

  Future<List<Map<String, dynamic>>> getDevelopmentSummaryHistory(String childId) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query('development_summaries', where: 'child_id = ?', whereArgs: [childId], orderBy: 'created_date DESC');
  }

  Future<List<Map<String, dynamic>>> getApprovedSummariesByChild(String childId) async {
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

  Future<int> updateDevelopmentSummaryStatus(int id, String status, String approvedBy, String approvedDate) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update('development_summaries', {
      'approval_status': status,
      'approved_by': approvedBy,
      'approved_date': approvedDate,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  // --- Referrals ---

  Future<List<Map<String, dynamic>>> getReferralsByChild(String childId) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query('referrals', where: 'child_id = ?', whereArgs: [childId], orderBy: 'referral_date DESC');
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

  Future<List<Map<String, dynamic>>> getNotificationsByParent(String parentUid) async {
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
    return await db.update('notifications', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> markAllNotificationsAsRead(String parentUid) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update('notifications', {'is_read': 1}, where: 'recipient_uid = ?', whereArgs: [parentUid]);
  }

  // --- Reports & Stats ---

  Future<Map<String, dynamic>> getDashboardStats(String today) async {
    if (kIsWeb) return {};
    final db = await instance.database;
    final totalChildren = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM children')) ?? 0;
    final totalTeachers = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users WHERE role = ?', ['teacher'])) ?? 0;
    final totalParents = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users WHERE role = ?', ['parent'])) ?? 0;
    final presentToday = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM attendance WHERE attendance_date = ? AND status = ?', [today, 'Present'])) ?? 0;
    final absentToday = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM attendance WHERE attendance_date = ? AND status = ?', [today, 'Absent'])) ?? 0;
    final completedEvaluations = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(DISTINCT child_id) FROM evaluations')) ?? 0;
    final pendingReferrals = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM referrals WHERE status = ?', ['Pending'])) ?? 0;

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
    final childMaps = await db.query('children', where: 'id = ?', whereArgs: [childLocalId]);
    if (childMaps.isEmpty) return {'assessments': [], 'attendance_rate': 0.0};
    final childId = childMaps.first['child_id'] as String;
    final assessmentMaps = await db.rawQuery('SELECT domain, AVG(score) as avg_score FROM evaluations WHERE child_id = ? GROUP BY domain', [childId]);
    final total = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM attendance WHERE child_id = ?', [childId])) ?? 0;
    final present = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM attendance WHERE child_id = ? AND status = ?', [childId, 'Present'])) ?? 0;
    return {
      'assessments': assessmentMaps.map((e) => {'domain': e['domain'], 'avg_score': (e['avg_score'] as num?)?.toDouble() ?? 0.0}).toList(),
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
    final maps = await db.query('file_uploads', where: 'file_id = ?', whereArgs: [fileId]);
    if (maps.isNotEmpty) return FileUploadModel.fromMap(maps.first);
    return null;
  }

  Future<List<FileUploadModel>> getUnsyncedFileUploads() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('file_uploads', where: 'is_synced = ?', whereArgs: [0]);
    return result.map((json) => FileUploadModel.fromMap(json)).toList();
  }

  Future<int> markFileUploadSynced(String fileId, String remoteUrl) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update(
      'file_uploads',
      {
        'remote_url': remoteUrl,
        'is_synced': 1,
      },
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
