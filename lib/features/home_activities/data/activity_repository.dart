import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

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
  Future<int> reviewSubmission(
    int submissionId,
    String review,
    String status, {
    int? score,
  });
  Future<String?> uploadSubmissionEvidence({
    required int submissionId,
    required String filePath,
    required String mediaType,
  });
  Future<String?> uploadSubmissionEvidenceBytes({
    required int submissionId,
    required Uint8List bytes,
    required String fileName,
    required String mediaType,
    String? contentType,
  });
  Future<String> refreshSubmissionEvidenceUrl({
    required int submissionId,
    required String expiredUrl,
    required String mediaType,
    String? fileName,
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
    bool evidenceRequired = true,
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
    bool evidenceRequired = true,
  }) async {
    final id = await _dbHelper.createHomeActivity(
      teacherId,
      childId,
      title,
      instructions,
      maxScore: maxScore,
      evidenceRequired: evidenceRequired,
    );

    if (await _connectivity.isOnline) {
      try {
        await _dbHelper.getActivitiesByChild(childId.toString());
      } catch (e) {
        debugPrint('Cloud Sync Failed: $e');
      }
    }

    await AuditLogger.log(
      action: 'Assign Activity',
      module: 'Home Activities',
      description:
          'Assigned activity: $title (Max Score: $maxScore) to child ID $childId.',
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

    // The web build has no SQLite database. Persist directly to Firestore with
    // a numeric ID so the existing submission workflow can use the same model.
    if (kIsWeb) {
      final webId = DateTime.now().microsecondsSinceEpoch.remainder(2147483647);
      final webActivity = newActivity.copyWith(id: webId);
      await _remote.uploadRecord(
        'activities',
        webId.toString(),
        webActivity.toMap(),
      );
      // The assignment itself is already stored. Do not keep the teacher's
      // dialog open while optional audit/notification work waits for separate
      // Firestore requests (one set of requests per child in a section).
      unawaited(
        AuditLogger.log(
          action: 'Assign Activity',
          module: 'Home Activities',
          description:
              'Assigned activity: ${activity.activityTitle} (Max Score: ${activity.maxScore}) to child ID ${activity.childId}.',
        ),
      );
      unawaited(
        NotificationRepositoryImpl().sendNotification(
          childId: activity.childId,
          type: 'home_activity',
          title: 'New Home Activity Assigned',
          body:
              'Teacher assigned "${activity.activityTitle}" (Max Score: ${activity.maxScore} pts, Due: ${activity.dueDate}).',
          referenceId: webId.toString(),
        ),
      );
      return webId;
    }

    final id = await _local.saveRecord('activities', newActivity.toMap());

    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord(
          'activities',
          id.toString(),
          newActivity.toMap(),
        );
        await _local.markAsSynced('activities', id);
      } catch (e) {
        debugPrint('Cloud Sync Failed: $e');
      }
    }

    await AuditLogger.log(
      action: 'Assign Activity',
      module: 'Home Activities',
      description:
          'Assigned activity: ${activity.activityTitle} (Max Score: ${activity.maxScore}) to child ID ${activity.childId}.',
    );

    // Send Parent Notification
    await NotificationRepositoryImpl().sendNotification(
      childId: activity.childId,
      type: 'home_activity',
      title: 'New Home Activity Assigned',
      body:
          'Teacher assigned "${activity.activityTitle}" (Max Score: ${activity.maxScore} pts, Due: ${activity.dueDate}).',
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
    // The web app stores activities directly in Firestore.  Updating through
    // the local database returned 0 here, leaving a successfully submitted
    // activity labelled "Assigned" in the parent's activity list.
    if (kIsWeb) {
      await FirebaseFirestore.instance.collection('activities').doc('$id').set({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        'server_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return 1;
    }

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
        debugPrint('Activity status sync failed: $e');
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

    // The web app has no SQLite cache.  Save the submission document directly
    // so the teacher can immediately see the proof uploaded by the parent.
    if (kIsWeb) {
      final webId = DateTime.now().microsecondsSinceEpoch.remainder(2147483647);
      final webSubmission = newSubmission.copyWith(id: webId, isSynced: true);
      await _remote.uploadRecord(
        'activity_submissions',
        webId.toString(),
        webSubmission.toMap(),
      );
      return webId;
    }

    final id = await _local.saveRecord(
      'activity_submissions',
      newSubmission.toMap(),
    );

    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord(
          'activity_submissions',
          id.toString(),
          newSubmission.toMap(),
        );
        await _local.markAsSynced('activity_submissions', id);
      } catch (e) {
        debugPrint('Cloud Sync Failed: $e');
      }
    }

    await AuditLogger.log(
      action: 'Submit Activity',
      module: 'Home Activities',
      description:
          'Parent submitted work for activity ID ${submission.activityId}.',
    );

    return id;
  }

  @override
  Future<ActivitySubmissionModel?> getSubmission(int activityId) async {
    if (kIsWeb) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;
      final snapshot = await FirebaseFirestore.instance
          .collection('activity_submissions')
          .where('activity_id', isEqualTo: activityId)
          .where('parent_uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (snapshot.docs.isEmpty) return null;
      final document = snapshot.docs.first;
      return ActivitySubmissionModel.fromMap({
        ...document.data(),
        'id': document.data()['id'] ?? int.tryParse(document.id),
      });
    }
    final data = await _dbHelper.getSubmissionByActivity(activityId);
    if (data != null) return ActivitySubmissionModel.fromMap(data);
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllSubmissions() async {
    if (kIsWeb) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get(const GetOptions(source: Source.server));
      final role = (profile.data()?['role'] as String? ?? '').toLowerCase();
      if (role != 'teacher' && role != 'parent' && role != 'admin') return [];

      Query<Map<String, dynamic>> submissionQuery = FirebaseFirestore.instance
          .collection('activity_submissions');
      Query<Map<String, dynamic>> activities = FirebaseFirestore.instance
          .collection('activities');
      Query<Map<String, dynamic>> children = FirebaseFirestore.instance
          .collection('children');
      if (role == 'teacher') {
        submissionQuery = submissionQuery.where(
          'teacher_uid',
          isEqualTo: currentUser.uid,
        );
        activities = activities.where(
          'assigned_teacher_uid',
          isEqualTo: currentUser.uid,
        );
        children = children.where('teacher_uid', isEqualTo: currentUser.uid);
      } else if (role == 'parent') {
        submissionQuery = submissionQuery.where(
          'parent_uid',
          isEqualTo: currentUser.uid,
        );
        activities = activities.where('parent_uid', isEqualTo: currentUser.uid);
        children = children.where('parent_uid', isEqualTo: currentUser.uid);
      }
      final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
        submissionQuery.get(const GetOptions(source: Source.server)),
        activities.get(const GetOptions(source: Source.server)),
        children.get(const GetOptions(source: Source.server)),
      ]);
      final submissionDocs = results[0];
      final activityDocs = results[1];
      final childDocs = results[2];
      final activitiesById = <String, Map<String, dynamic>>{
        for (final document in activityDocs.docs)
          (document.data()['id'] ?? document.id).toString(): document.data(),
      };
      final childrenById = <String, Map<String, dynamic>>{
        for (final document in childDocs.docs)
          (document.data()['child_id'] ?? document.id).toString(): document
              .data(),
      };

      final submissionRecords = submissionDocs.docs.map((document) {
        final data = document.data();
        final activity =
            activitiesById[data['activity_id'].toString()] ?? const {};
        final child = childrenById[data['child_id'].toString()] ?? const {};
        return <String, dynamic>{
          ...data,
          'id': data['id'] ?? int.tryParse(document.id),
          'activity_title': activity['activity_title'] ?? 'Home activity',
          'max_score': activity['max_score'] ?? 20,
          'first_name': child['first_name'] ?? 'Child',
          'last_name': child['last_name'] ?? '',
          'parent_name': child['parent_name'] ?? 'Parent/Guardian',
        };
      }).toList();
      submissionRecords.sort(
        (a, b) => (b['submission_date']?.toString() ?? '').compareTo(
          a['submission_date']?.toString() ?? '',
        ),
      );
      return submissionRecords;
    }
    return await _dbHelper.getAllSubmissions();
  }

  @override
  Future<int> reviewSubmission(
    int submissionId,
    String review,
    String status, {
    int? score,
  }) async {
    if (kIsWeb) {
      await FirebaseFirestore.instance
          .collection('activity_submissions')
          .doc(submissionId.toString())
          .set({
            'teacher_review': review,
            'review_status': status,
            if (score != null) 'score': score,
            'updated_at': DateTime.now().toIso8601String(),
            'server_updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      return 1;
    }
    final result = await _dbHelper.updateSubmissionReview(
      submissionId,
      review,
      status,
      score: score,
    );

    await AuditLogger.log(
      action: 'Review Activity',
      module: 'Home Activities',
      description:
          'Teacher reviewed activity submission ID $submissionId as $status with score ${score ?? 'N/A'}.',
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

  @override
  Future<String?> uploadSubmissionEvidenceBytes({
    required int submissionId,
    required Uint8List bytes,
    required String fileName,
    required String mediaType,
    String? contentType,
  }) async {
    final url = await _fileUploadRepo.uploadBytes(
      bucket: SupabaseConfig.homeActivityEvidence,
      entityId: submissionId.toString(),
      category: SupabaseConfig.homeActivityCategory,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      docCollection: 'activity_submissions',
      urlFieldName: 'evidence_url',
    );
    if (url == null) return null;

    final metadata = <String, dynamic>{
      'evidence_media_type': mediaType,
      'evidence_file_name': fileName,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await FirebaseFirestore.instance
        .collection('activity_submissions')
        .doc(submissionId.toString())
        .set(metadata, SetOptions(merge: true));
    if (!kIsWeb) {
      await _dbHelper.updateActivitySubmissionEvidence(
        submissionId,
        evidenceUrl: url,
        evidenceMediaType: mediaType,
        evidenceFileName: fileName,
      );
    }
    return url;
  }

  @override
  Future<String> refreshSubmissionEvidenceUrl({
    required int submissionId,
    required String expiredUrl,
    required String mediaType,
    String? fileName,
  }) async {
    final refreshedUrl = await _fileUploadRepo.refreshSignedUrl(
      bucket: SupabaseConfig.homeActivityEvidence,
      signedUrl: expiredUrl,
    );
    final metadata = <String, dynamic>{
      'evidence_url': refreshedUrl,
      'evidence_media_type': mediaType,
      'updated_at': DateTime.now().toIso8601String(),
      'server_updated_at': FieldValue.serverTimestamp(),
      if (fileName != null && fileName.trim().isNotEmpty)
        'evidence_file_name': fileName,
    };
    await FirebaseFirestore.instance
        .collection('activity_submissions')
        .doc(submissionId.toString())
        .set(metadata, SetOptions(merge: true));
    if (!kIsWeb) {
      await _dbHelper.updateActivitySubmissionEvidence(
        submissionId,
        evidenceUrl: refreshedUrl,
        evidenceMediaType: mediaType,
        evidenceFileName: fileName,
      );
    }
    return refreshedUrl;
  }
}
