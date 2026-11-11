import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    // Browser connectivity reports are not reliable enough to decide whether
    // Firestore can accept a write. A web evaluation has no SQLite fallback,
    // so always attempt its authoritative cloud save.
    final canSync = kIsWeb || await _connectivity.isOnline;
    final newEval = evaluation.copyWith(updatedAt: now, isSynced: canSync);

    // 1. Save locally first on mobile. Web has no SQLite database, so it
    // writes an authoritative, unique Firestore evaluation document instead
    // of silently reusing the local placeholder ID 0.
    final id = kIsWeb
        ? DateTime.now().microsecondsSinceEpoch
        : await _local.saveRecord('evaluations', newEval.toMap());

    // 2. Sync to Cloud if online
    if (canSync) {
      try {
        await _remote.uploadRecord(
          'evaluations',
          id.toString(),
          newEval.toMap(),
          isCreate: true,
        );
        await _local.markAsSynced('evaluations', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    // 3. Log Action
    await AuditLogger.log(
      action: 'Add Evaluation',
      module: 'Evaluation',
      description:
          'Added evaluation for domain: ${evaluation.domain} with score: ${evaluation.score}.',
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
