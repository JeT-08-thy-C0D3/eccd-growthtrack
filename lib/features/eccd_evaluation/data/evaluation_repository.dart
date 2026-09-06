import '../../../core/database/database_helper.dart';
import '../domain/evaluation_model.dart';

abstract class EvaluationRepository {
  Future<int> addEvaluation(EvaluationModel evaluation);
  Future<List<Map<String, dynamic>>> getHistory(String childId);
  Future<List<Map<String, dynamic>>> getLatest(String childId);
}

class EvaluationRepositoryImpl implements EvaluationRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<int> addEvaluation(EvaluationModel evaluation) async {
    return await _dbHelper.insertEvaluation(evaluation.toMap());
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
