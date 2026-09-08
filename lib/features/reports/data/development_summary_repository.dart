import '../../../core/database/database_helper.dart';
import '../domain/development_summary_model.dart';

abstract class DevelopmentSummaryRepository {
  Future<int> addSummary(DevelopmentSummaryModel summary);
  Future<List<Map<String, dynamic>>> getHistory(String childId);
  Future<int> updateStatus(int id, String status, String approvedBy, String approvedDate);
}

class DevelopmentSummaryRepositoryImpl implements DevelopmentSummaryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<int> addSummary(DevelopmentSummaryModel summary) async {
    return await _dbHelper.insertDevelopmentSummary(summary.toMap());
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory(String childId) async {
    return await _dbHelper.getDevelopmentSummaryHistory(childId);
  }

  @override
  Future<int> updateStatus(int id, String status, String approvedBy, String approvedDate) async {
    return await _dbHelper.updateDevelopmentSummaryStatus(id, status, approvedBy, approvedDate);
  }
}
