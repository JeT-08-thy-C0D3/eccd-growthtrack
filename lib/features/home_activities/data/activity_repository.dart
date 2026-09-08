import '../../../core/database/database_helper.dart';
import '../domain/activity_model.dart';
import '../domain/activity_submission_model.dart';

abstract class ActivityRepository {
  Future<int> createActivity(ActivityModel activity);
  Future<List<ActivityModel>> getActivitiesForChild(String childId);
  Future<List<ActivityModel>> getAllActivities();
  Future<int> updateActivityStatus(int id, String status);
  
  Future<int> submitActivity(ActivitySubmissionModel submission);
  Future<ActivitySubmissionModel?> getSubmission(int activityId);
  Future<List<Map<String, dynamic>>> getAllSubmissions();
  Future<int> reviewSubmission(int submissionId, String review, String status);
}

class ActivityRepositoryImpl implements ActivityRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<int> createActivity(ActivityModel activity) async {
    return await _dbHelper.insertActivity(activity.toMap());
  }

  @override
  Future<List<ActivityModel>> getActivitiesForChild(String childId) async {
    final data = await _dbHelper.getActivitiesByChild(childId);
    return data.map((e) => ActivityModel.fromMap(e)).toList();
  }

  @override
  Future<List<ActivityModel>> getAllActivities() async {
    final data = await _dbHelper.getAllActivities();
    return data.map((e) => ActivityModel.fromMap(e)).toList();
  }

  @override
  Future<int> updateActivityStatus(int id, String status) async {
    return await _dbHelper.updateActivityStatus(id, status);
  }

  @override
  Future<int> submitActivity(ActivitySubmissionModel submission) async {
    return await _dbHelper.insertActivitySubmission(submission.toMap());
  }

  @override
  Future<ActivitySubmissionModel?> getSubmission(int activityId) async {
    final data = await _dbHelper.getSubmissionByActivity(activityId);
    if (data != null) return ActivitySubmissionModel.fromMap(data);
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllSubmissions() async {
    return await _dbHelper.getAllSubmissions();
  }

  @override
  Future<int> reviewSubmission(int submissionId, String review, String status) async {
    return await _dbHelper.updateSubmissionReview(submissionId, review, status);
  }
}
