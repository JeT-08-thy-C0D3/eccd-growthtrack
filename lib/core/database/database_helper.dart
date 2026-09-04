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
        name $textType,
        email $textType UNIQUE,
        password $textType,
        role $textType
      )
    ''');

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
