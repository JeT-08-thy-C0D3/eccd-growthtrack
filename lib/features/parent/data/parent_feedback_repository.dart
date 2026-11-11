import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    // Web has no SQLite queue for this record. Always try the signed-in
    // Firestore session; Chrome can report no network despite Firebase being
    // reachable.
    final canSync = kIsWeb || await _connectivity.isOnline;
    final newFeedback = feedback.copyWith(updatedAt: now, isSynced: canSync);

    // Web has no SQLite auto-increment ID. Use a unique numeric document ID so
    // a new feedback item can be read back, edited, and included in teacher
    // triangulation instead of repeatedly overwriting document "0".
    final id = kIsWeb
        ? DateTime.now().microsecondsSinceEpoch
        : await _local.saveRecord('parent_feedback', newFeedback.toMap());

    if (canSync) {
      try {
        final cloudData = newFeedback.toMap()
          ..['parent_uid'] = FirebaseAuth.instance.currentUser?.uid;
        await _remote.uploadRecord(
          'parent_feedback',
          id.toString(),
          cloudData,
          isCreate: true,
        );
        final serverTime = await _remote.fetchServerUpdatedAt(
          'parent_feedback',
          id.toString(),
        );
        if (serverTime != null) {
          final officialTime = DateFormat('yyyy-MM-dd HH:mm:ss \'UTC\'')
              .format(serverTime);
          await _dbHelper.database.then(
            (db) => db.update(
              'parent_feedback',
              {'submission_date': officialTime, 'updated_at': officialTime},
              where: 'id = ?',
              whereArgs: [id],
            ),
          );
        }
        await _local.markAsSynced('parent_feedback', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    await AuditLogger.log(
      action: 'Submit Feedback',
      module: 'Parent Module',
      description:
          'Parent submitted developmental observation for child ID ${feedback.childId}.',
    );

    return id;
  }

  @override
  Future<List<ParentFeedbackModel>> getFeedbackHistory(String childId) async {
    if (kIsWeb) {
      final snapshot = await FirebaseFirestore.instance
          .collection('parent_feedback')
          .where('child_id', isEqualTo: childId)
          .get(const GetOptions(source: Source.server));
      final feedback = snapshot.docs
          .map(
            (document) => ParentFeedbackModel.fromMap({
              ...document.data(),
              'id': int.tryParse(document.id),
            }),
          )
          .toList();
      feedback.sort((a, b) => b.submissionDate.compareTo(a.submissionDate));
      return feedback;
    }
    final List<Map<String, dynamic>> maps = await _dbHelper.getFeedbackByChild(
      childId,
    );
    return maps.map((map) => ParentFeedbackModel.fromMap(map)).toList();
  }

  @override
  Future<int> updateFeedback(ParentFeedbackModel feedback) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final canSync = kIsWeb || await _connectivity.isOnline;
    final updatedFeedback = feedback.copyWith(
      updatedAt: now,
      isSynced: canSync,
    );

    final id = kIsWeb
        ? feedback.id ??
              (throw StateError(
                'This feedback record has no cloud identifier and cannot be updated.',
              ))
        : await _local.saveRecord('parent_feedback', updatedFeedback.toMap());

    if (canSync) {
      try {
        final cloudData = updatedFeedback.toMap()
          ..['parent_uid'] = FirebaseAuth.instance.currentUser?.uid;
        await _remote.uploadRecord('parent_feedback', id.toString(), cloudData);
        final serverTime = await _remote.fetchServerUpdatedAt(
          'parent_feedback',
          id.toString(),
        );
        if (serverTime != null) {
          final officialTime = DateFormat('yyyy-MM-dd HH:mm:ss \'UTC\'')
              .format(serverTime);
          await _dbHelper.database.then(
            (db) => db.update(
              'parent_feedback',
              {'updated_at': officialTime},
              where: 'id = ?',
              whereArgs: [id],
            ),
          );
        }
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
