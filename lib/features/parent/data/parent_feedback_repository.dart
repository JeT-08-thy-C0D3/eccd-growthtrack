import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../domain/parent_feedback_model.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/utils/audit_logger.dart';

abstract class ParentFeedbackRepository {
  Future<int> submitFeedback(ParentFeedbackModel feedback);
  Future<List<ParentFeedbackModel>> getFeedbackHistory(String childId);
  Future<int> updateFeedback(ParentFeedbackModel feedback);
  Future<int> deleteFeedback(int id);
}

class ParentFeedbackRepositoryImpl implements ParentFeedbackRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  Future<int> submitFeedback(ParentFeedbackModel feedback) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final newFeedback = feedback.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    final id = await _local.saveRecord('parent_feedback', newFeedback.toMap());
    
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('parent_feedback', id.toString(), newFeedback.toMap());
        await _local.markAsSynced('parent_feedback', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    await AuditLogger.log(
      action: 'Submit Feedback',
      module: 'Parent Module',
      description: 'Parent submitted developmental observation for child ID ${feedback.childId}.',
    );

    return id;
  }

  @override
  Future<List<ParentFeedbackModel>> getFeedbackHistory(String childId) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.getFeedbackByChild(childId);
    return maps.map((map) => ParentFeedbackModel.fromMap(map)).toList();
  }

  @override
  Future<int> updateFeedback(ParentFeedbackModel feedback) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final updatedFeedback = feedback.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    final id = await _local.saveRecord('parent_feedback', updatedFeedback.toMap());
    
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('parent_feedback', id.toString(), updatedFeedback.toMap());
        await _local.markAsSynced('parent_feedback', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    return id;
  }

  @override
  Future<int> deleteFeedback(int id) async {
    return await _dbHelper.delete('parent_feedback', id);
  }
}
