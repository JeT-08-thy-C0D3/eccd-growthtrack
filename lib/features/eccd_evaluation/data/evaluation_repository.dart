import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/audit_logger.dart';
import '../domain/evaluation_model.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../core/network/connectivity_service.dart';

abstract class EvaluationRepository {
  Future<int> addEvaluation(EvaluationModel evaluation);
  Future<List<Map<String, dynamic>>> getHistory(String childId);
  Future<List<Map<String, dynamic>>> getLatest(String childId);
}

class EvaluationRepositoryImpl implements EvaluationRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  Future<int> addEvaluation(EvaluationModel evaluation) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final newEval = evaluation.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    // 1. Save Locally
    final id = await _local.saveRecord('evaluations', newEval.toMap());
    
    // 2. Sync to Cloud if online
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('evaluations', id.toString(), newEval.toMap());
        await _local.markAsSynced('evaluations', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    // 3. Log Action
    await AuditLogger.log(
      action: 'Add Evaluation',
      module: 'Evaluation',
      description: 'Added evaluation for domain: ${evaluation.domain} with score: ${evaluation.score}.',
    );
    
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory(String childId) async {
    return await _dbHelper.getChildEvaluationHistory(childId);
  }

  @override
  Future<List<Map<String, dynamic>>> getLatest(String childId) async {
    return await _dbHelper.getLatestEvaluations(childId);
  }
}
