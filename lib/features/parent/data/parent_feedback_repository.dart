import '../../../core/database/database_helper.dart';
import '../domain/parent_feedback_model.dart';

abstract class ParentFeedbackRepository {
  Future<int> submitFeedback(ParentFeedbackModel feedback);
  Future<List<ParentFeedbackModel>> getFeedbackHistory(String childId);
  Future<int> updateFeedback(ParentFeedbackModel feedback);
  Future<int> deleteFeedback(int id);
}

class ParentFeedbackRepositoryImpl implements ParentFeedbackRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<int> submitFeedback(ParentFeedbackModel feedback) async {
    return await _dbHelper.insertFeedback(feedback.toMap());
  }

  @override
  Future<List<ParentFeedbackModel>> getFeedbackHistory(String childId) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.getFeedbackByChild(childId);
    return maps.map((map) => ParentFeedbackModel.fromMap(map)).toList();
  }

  @override
  Future<int> updateFeedback(ParentFeedbackModel feedback) async {
    return await _dbHelper.updateFeedback(feedback.toMap());
  }

  @override
  Future<int> deleteFeedback(int id) async {
    return await _dbHelper.deleteFeedback(id);
  }
}
