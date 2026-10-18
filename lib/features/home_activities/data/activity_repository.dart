import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../domain/activity_model.dart';
import '../domain/activity_submission_model.dart';
import '../../../shared/models/child_model.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../data/repositories/file_upload_repository.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/utils/audit_logger.dart';
import '../../notification/data/notification_repository.dart';

abstract class ActivityRepository {
  Future<int> createActivity(ActivityModel activity);
  Future<List<ActivityModel>> getActivitiesForChild(String childId);
  Future<List<ActivityModel>> getAllActivities();
  Future<int> updateActivityStatus(int id, String status);
  
  Future<int> submitActivity(ActivitySubmissionModel submission);
  Future<ActivitySubmissionModel?> getSubmission(int activityId);
  Future<List<Map<String, dynamic>>> getAllSubmissions();
  Future<int> reviewSubmission(int submissionId, String review, String status, {int? score});
  Future<String?> uploadSubmissionEvidence({
    required int submissionId,
    required String filePath,
    required String mediaType,
  });

  // Added for Teacher Home Activities workflow
  Future<List<ActivityModel>> getHomeActivitiesByTeacher(int teacherId);
  Future<List<ChildModel>> getTeacherChildren(int teacherId);
  Future<int> createHomeActivity({
    required int teacherId,
    required int childId,
    required String title,
    required String instructions,
    int maxScore = 20,
  });
}

class ActivityRepositoryImpl implements ActivityRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();
  final FileUploadRepository _fileUploadRepo = FileUploadRepository();

  @override
  Future<List<ActivityModel>> getHomeActivitiesByTeacher(int teacherId) async {
    final data = await _dbHelper.getHomeActivitiesByTeacher(teacherId);
    return data.map((e) => ActivityModel.fromMap(e)).toList();
  }

  @override
  Future<List<ChildModel>> getTeacherChildren(int teacherId) async {
    final user = await _dbHelper.readUser(teacherId);
    if (user == null) return [];
    return await _dbHelper.readChildrenByTeacher(user.uid);
  }

  @override
  Future<int> createHomeActivity({
    required int teacherId,
    required int childId,
    required String title,
    required String instructions,
    int maxScore = 20,
  }) async {
    final id = await _dbHelper.createHomeActivity(teacherId, childId, title, instructions, maxScore: maxScore);
    
    if (await _connectivity.isOnline) {
      try {
        await _dbHelper.getActivitiesByChild(childId.toString());
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    await AuditLogger.log(
      action: 'Assign Activity',
      module: 'Home Activities',
      description: 'Assigned activity: $title (Max Score: $maxScore) to child ID $childId.',
    );

    return id;
  }

  @override
  Future<int> createActivity(ActivityModel activity) async {
    // Keep timestamps in the same ISO format used by the incremental cloud sync query.
    final now = DateTime.now().toIso8601String();
    final newActivity = activity.copyWith(
      updatedAt: now,
      // Only mark synced after the cloud upload succeeds below.
      isSynced: false,
    );

    final id = await _local.saveRecord('activities', newActivity.toMap());
    
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('activities', id.toString(), newActivity.toMap());
        await _local.markAsSynced('activities', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    await AuditLogger.log(
      action: 'Assign Activity',
      module: 'Home Activities',
      description: 'Assigned activity: ${activity.activityTitle} (Max Score: ${activity.maxScore}) to child ID ${activity.childId}.',
    );

    // Send Parent Notification
    await NotificationRepositoryImpl().sendNotification(
      childId: activity.childId,
      type: 'home_activity',
      title: 'New Home Activity Assigned',
      body: 'Teacher assigned "${activity.activityTitle}" (Max Score: ${activity.maxScore} pts, Due: ${activity.dueDate}).',
      referenceId: id.toString(),
    );

    return id;
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
    final result = await _dbHelper.updateActivityStatus(id, status);
    if (result == 0) return result;

    if (await _connectivity.isOnline) {
      try {
        final activities = await _dbHelper.getAllActivities();
        Map<String, dynamic>? activity;
        for (final item in activities) {
          if (item['id'] == id) {
            activity = item;
            break;
          }
        }
        if (activity != null) {
          await _remote.uploadRecord('activities', id.toString(), activity);
          await _local.markAsSynced('activities', id);
        }
      } catch (e) {
        // The sync service will retry this unsynced update when online.
        print('Activity status sync failed: $e');
      }
    }
    return result;
  }

  @override
  Future<int> submitActivity(ActivitySubmissionModel submission) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final newSubmission = submission.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    final id = await _local.saveRecord('activity_submissions', newSubmission.toMap());
    
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('activity_submissions', id.toString(), newSubmission.toMap());
        await _local.markAsSynced('activity_submissions', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    await AuditLogger.log(
      action: 'Submit Activity',
      module: 'Home Activities',
      description: 'Parent submitted work for activity ID ${submission.activityId}.',
    );

    return id;
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
  Future<int> reviewSubmission(int submissionId, String review, String status, {int? score}) async {
    final result = await _dbHelper.updateSubmissionReview(submissionId, review, status, score: score);
    
    await AuditLogger.log(
      action: 'Review Activity',
      module: 'Home Activities',
      description: 'Teacher reviewed activity submission ID $submissionId as $status with score ${score ?? 'N/A'}.',
    );

    return result;
  }

  @override
  Future<String?> uploadSubmissionEvidence({
    required int submissionId,
    required String filePath,
    required String mediaType,
  }) async {
    final url = await _fileUploadRepo.uploadFile(
      bucket: SupabaseConfig.homeActivityEvidence,
      entityId: submissionId.toString(),
      category: SupabaseConfig.homeActivityCategory,
      filePath: filePath,
      docCollection: 'activity_submissions',
      urlFieldName: 'evidence_url',
    );
    if (url != null) {
      await _dbHelper.updateActivitySubmissionEvidence(
        submissionId,
        evidenceUrl: url,
        evidenceMediaType: mediaType,
      );
    }
    return url;
  }
}
