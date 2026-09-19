import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../domain/clarification_model.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/utils/audit_logger.dart';

abstract class ClarificationRepository {
  Future<int> sendRequest(ClarificationModel request);
  Future<List<ClarificationModel>> getRequestsByChild(String childId);
  Future<List<ClarificationModel>> getRequestsByParent(int parentId);
  Future<int> respondToRequest(int id, String response, int teacherId);
}

class ClarificationRepositoryImpl implements ClarificationRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  Future<int> sendRequest(ClarificationModel request) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final newRequest = request.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    final id = await _local.saveRecord('clarifications', newRequest.toMap());
    
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('clarifications', id.toString(), newRequest.toMap());
        await _local.markAsSynced('clarifications', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    await AuditLogger.log(
      action: 'Clarification Request',
      module: 'Parent Module',
      description: 'Parent ID ${request.parentId} sent a clarification request for child ID ${request.childId}.',
    );

    return id;
  }

  @override
  Future<List<ClarificationModel>> getRequestsByChild(String childId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clarifications',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ClarificationModel.fromMap(map)).toList();
  }

  @override
  Future<List<ClarificationModel>> getRequestsByParent(int parentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clarifications',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ClarificationModel.fromMap(map)).toList();
  }

  @override
  Future<int> respondToRequest(int id, String response, int teacherId) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    
    // Simplified update for prototype
    final db = await _dbHelper.database;
    final result = await db.update(
      'clarifications',
      {
        'response': response,
        'teacher_id': teacherId,
        'status': 'Responded',
        'updated_at': now,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await AuditLogger.log(
      action: 'Respond to Clarification',
      module: 'Teacher Module',
      description: 'Teacher ID $teacherId responded to clarification request ID $id.',
    );

    return result;
  }
}
