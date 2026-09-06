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

    // Add a default admin for testing purposes
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

    // Children Table
    await db.execute('''
      CREATE TABLE children (
        id $idType,
        name $textType,
        dob $textType,
        gender $textType,
        teacher_id $integerType,
        parent_id $integerType,
        FOREIGN KEY (teacher_id) REFERENCES users (id),
        FOREIGN KEY (parent_id) REFERENCES users (id)
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

    // Attendance Table
    await db.execute('''
      CREATE TABLE attendance (
        id $idType,
        child_id $integerType,
        date $textType,
        status $textType,
        FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE
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

  // --- CRUD Operations for Referrals ---

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
      SELECT r.*, c.name as child_name
      FROM referrals r
      JOIN children c ON r.child_id = c.id
      WHERE r.teacher_id = ?
      ORDER BY r.date DESC
    ''', [teacherId]);
  }

  // --- CRUD Operations for Reports/Analytics ---

  Future<Map<String, dynamic>> getChildProgressSummary(int childId) async {
    final db = await instance.database;
    
    // Get average scores per domain
    final List<Map<String, dynamic>> assessmentData = await db.rawQuery('''
      SELECT domain, AVG(score) as avg_score
      FROM assessments
      WHERE child_id = ?
      GROUP BY domain
    ''', [childId]);

    // Get attendance rate
    final List<Map<String, dynamic>> attendanceData = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) as present
      FROM attendance
      WHERE child_id = ?
    ''', [childId]);

    double attendanceRate = 0;
    if (attendanceData.isNotEmpty && attendanceData.first['total'] > 0) {
      attendanceRate = (attendanceData.first['present'] / attendanceData.first['total']) * 100;
    }

    return {
      'assessments': assessmentData,
      'attendance_rate': attendanceRate,
    };
  }

  // --- CRUD Operations for Home Activities ---

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
      SELECT h.*, c.name as child_name
      FROM home_activities h
      JOIN children c ON h.child_id = c.id
      WHERE h.teacher_id = ?
      ORDER BY h.date_assigned DESC
    ''', [teacherId]);
  }

  // --- CRUD Operations for Attendance ---

  Future<int> markAttendance(int childId, String date, String status) async {
    final db = await instance.database;
    
    // Check if record exists for this child and date
    final existing = await db.query(
      'attendance',
      where: 'child_id = ? AND date = ?',
      whereArgs: [childId, date],
    );

    if (existing.isNotEmpty) {
      // Update existing
      return await db.update(
        'attendance',
        {'status': status},
        where: 'child_id = ? AND date = ?',
        whereArgs: [childId, date],
      );
    } else {
      // Insert new
      return await db.insert('attendance', {
        'child_id': childId,
        'date': date,
        'status': status,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getAttendanceForDate(int teacherId, String date) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.id, c.name, IFNULL(a.status, 'none') as status
      FROM children c
      LEFT JOIN attendance a ON c.id = a.child_id AND a.date = ?
      WHERE c.teacher_id = ?
    ''', [date, teacherId]);
  }

  // --- CRUD Operations for Users ---

  Future<int> createUser(UserModel user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<UserModel?> readUser(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      columns: ['id', 'name', 'email', 'password', 'role'],
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

  // --- CRUD Operations for Children ---

  Future<int> createChild(ChildModel child) async {
    final db = await instance.database;
    return await db.insert('children', child.toMap());
  }

  Future<List<ChildModel>> readChildrenByTeacher(int teacherId) async {
    final db = await instance.database;
    final result = await db.query(
      'children',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
    );
    return result.map((json) => ChildModel.fromMap(json)).toList();
  }

  // --- CRUD Operations for Assessments ---

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

  // --- Generic Delete and Update ---

  Future<int> update(String table, Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update(table, row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, int id) async {
    final db = await instance.database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
