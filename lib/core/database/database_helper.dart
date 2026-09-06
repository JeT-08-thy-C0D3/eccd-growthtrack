import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/child_model.dart';
import '../../shared/models/assessment_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('eccd_growthtrack.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const textUniqueType = 'TEXT NOT NULL UNIQUE';

    // Users Table
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        uid $textType,
        name $textType,
        email $textType UNIQUE,
        password $textType,
        role $textType
      )
    ''');

    // Default users for testing
    await db.insert('users', {
      'uid': 'admin-001',
      'name': 'System Admin',
      'email': 'admin@eccd.com',
      'password': 'password123',
      'role': 'admin'
    });
    
    await db.insert('users', {
      'uid': 'teacher-001',
      'name': 'Teacher Jane',
      'email': 'teacher@eccd.com',
      'password': 'password123',
      'role': 'teacher'
    });

    await db.insert('users', {
      'uid': 'parent-001',
      'name': 'Parent John',
      'email': 'parent@eccd.com',
      'password': 'password123',
      'role': 'parent'
    });

    // Children Table - Updated Schema
    await db.execute('''
      CREATE TABLE children (
        id $idType,
        child_id $textUniqueType,
        first_name $textType,
        last_name $textType,
        birth_date $textType,
        age $integerType,
        gender $textType,
        address $textType,
        parent_name $textType,
        teacher_name $textType
      )
    ''');

    // Assessments Table
    await db.execute('''
      CREATE TABLE assessments (
        id $idType,
        child_id $integerType,
        date $textType,
        domain $textType,
        score $integerType,
        remarks $textType,
        FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE
      )
    ''');

    // Milestones Table
    await db.execute('''
      CREATE TABLE milestones (
        id $idType,
        child_id $integerType,
        milestone_text $textType,
        status $textType,
        FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE
      )
    ''');

    // Attendance Table - Updated Schema for RFID readiness
    await db.execute('''
      CREATE TABLE attendance (
        id $idType,
        child_id $textType,
        attendance_date $textType,
        attendance_time $textType,
        status $textType,
        FOREIGN KEY (child_id) REFERENCES children (child_id) ON DELETE CASCADE
      )
    ''');

    // Home Activities Table
    await db.execute('''
      CREATE TABLE home_activities (
        id $idType,
        teacher_id $integerType,
        child_id $integerType,
        title $textType,
        description $textType,
        status $textType,
        date_assigned $textType,
        FOREIGN KEY (teacher_id) REFERENCES users (id),
        FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE
      )
    ''');

    // Referrals Table
    await db.execute('''
      CREATE TABLE referrals (
        id $idType,
        child_id $integerType,
        teacher_id $integerType,
        category $textType,
        reason $textType,
        date $textType,
        status $textType,
        FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE,
        FOREIGN KEY (teacher_id) REFERENCES users (id)
      )
    ''');
  }

  // --- CRUD Operations for Children ---

  Future<int> insertChild(ChildModel child) async {
    final db = await instance.database;
    return await db.insert('children', child.toMap());
  }

  Future<List<ChildModel>> getAllChildren() async {
    final db = await instance.database;
    final result = await db.query('children', orderBy: 'last_name ASC');
    return result.map((json) => ChildModel.fromMap(json)).toList();
  }

  Future<int> updateChild(ChildModel child) async {
    final db = await instance.database;
    return await db.update(
      'children',
      child.toMap(),
      where: 'id = ?',
      whereArgs: [child.id],
    );
  }

  Future<int> deleteChild(int id) async {
    final db = await instance.database;
    return await db.delete(
      'children',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Other CRUD Operations (Keep existing or update as needed) ---

  Future<int> createUser(UserModel user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<UserModel?> readUser(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<UserModel>> readAllUsers() async {
    final db = await instance.database;
    final result = await db.query('users');
    return result.map((json) => UserModel.fromMap(json)).toList();
  }

  // Note: Previous methods like readChildrenByTeacher/Parent need update if they used teacher_id column
  // For simplicity in this module, I'll focus on the new children CRUD.
  
  // --- Updated Attendance Operations for RFID Module ---

  Future<int> insertAttendance(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('attendance', row);
  }

  Future<List<Map<String, dynamic>>> getChildAttendanceHistory(String childId) async {
    final db = await instance.database;
    return await db.query(
      'attendance',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'attendance_date DESC, attendance_time DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAttendanceSummaryByDate(String date) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT a.*, c.first_name, c.last_name
      FROM attendance a
      JOIN children c ON a.child_id = c.child_id
      WHERE a.attendance_date = ?
    ''', [date]);
  }

  Future<int> createAssessment(AssessmentModel assessment) async {
    final db = await instance.database;
    return await db.insert('assessments', assessment.toMap());
  }

  Future<List<AssessmentModel>> readAssessmentsByChild(int childId) async {
    final db = await instance.database;
    final result = await db.query(
      'assessments',
      where: 'child_id = ?',
      whereArgs: [childId],
    );
    return result.map((json) => AssessmentModel.fromMap(json)).toList();
  }

  Future<Map<String, dynamic>> getChildProgressSummary(int childId) async {
    final db = await instance.database;
    final assessmentData = await db.rawQuery('''
      SELECT domain, AVG(score) as avg_score
      FROM assessments
      WHERE child_id = ?
      GROUP BY domain
    ''', [childId]);

    final attendanceData = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) as present
      FROM attendance
      WHERE child_id = ?
    ''', [childId]);

    double attendanceRate = 0;
    if (attendanceData.isNotEmpty && (attendanceData.first['total'] as int) > 0) {
      attendanceRate = ((attendanceData.first['present'] as int) / (attendanceData.first['total'] as int)) * 100;
    }

    return {
      'assessments': assessmentData,
      'attendance_rate': attendanceRate,
    };
  }

  Future<int> createHomeActivity(int teacherId, int childId, String title, String description) async {
    final db = await instance.database;
    return await db.insert('home_activities', {
      'teacher_id': teacherId,
      'child_id': childId,
      'title': title,
      'description': description,
      'status': 'Pending',
      'date_assigned': DateTime.now().toIso8601String().split('T')[0],
    });
  }

  Future<List<Map<String, dynamic>>> getHomeActivitiesByTeacher(int teacherId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT h.*, c.first_name || ' ' || c.last_name as child_name
      FROM home_activities h
      JOIN children c ON h.child_id = c.id
      WHERE h.teacher_id = ?
      ORDER BY h.date_assigned DESC
    ''', [teacherId]);
  }

  Future<List<ChildModel>> readChildrenByTeacher(int teacherId) async {
    // This needs to be adapted since we don't have teacher_id in children table anymore, 
    // but the user asked for teacher_name. 
    // For this module, I'll just return all for now or filter by teacher_name if I had the teacher object.
    final db = await instance.database;
    final result = await db.query('children');
    return result.map((json) => ChildModel.fromMap(json)).toList();
  }

  Future<List<ChildModel>> readChildrenByParent(int parentId) async {
    final db = await instance.database;
    final result = await db.query('children');
    return result.map((json) => ChildModel.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getHomeActivitiesByChild(int childId) async {
    final db = await instance.database;
    return await db.query(
      'home_activities',
      where: 'child_id = ?',
      orderBy: 'date_assigned DESC',
    );
  }

  Future<int> updateHomeActivityStatus(int activityId, String status) async {
    final db = await instance.database;
    return await db.update(
      'home_activities',
      {'status': status},
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }

  Future<int> createReferral(int childId, int teacherId, String category, String reason) async {
    final db = await instance.database;
    return await db.insert('referrals', {
      'child_id': childId,
      'teacher_id': teacherId,
      'category': category,
      'reason': reason,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'status': 'Pending',
    });
  }

  Future<List<Map<String, dynamic>>> getReferralsByTeacher(int teacherId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT r.*, c.first_name || ' ' || c.last_name as child_name
      FROM referrals r
      JOIN children c ON r.child_id = c.id
      WHERE r.teacher_id = ?
      ORDER BY r.date DESC
    ''', [teacherId]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
