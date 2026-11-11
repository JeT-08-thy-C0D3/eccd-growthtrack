import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/database/database_helper.dart';
import '../domain/triangulation_model.dart';
import '../domain/triangulation_repository.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/utils/audit_logger.dart';

class TriangulationRepositoryImpl implements TriangulationRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  Future<int> saveTriangulation(TriangulationModel triangulation) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final canSync = kIsWeb || await _connectivity.isOnline;
    final newTri = triangulation.copyWith(updatedAt: now, isSynced: canSync);

    // SQLite is unavailable on web. Use a stable, unique numeric document ID
    // so the saved analysis can immediately be selected by AI Summary.
    final id = kIsWeb
        ? DateTime.now().millisecondsSinceEpoch
        : await _local.saveRecord('triangulations', newTri.toMap());

    if (canSync) {
      try {
        await _remote.uploadRecord(
          'triangulations',
          id.toString(),
          newTri.toMap(),
          isCreate: true,
        );
        await _local.markAsSynced('triangulations', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    await AuditLogger.log(
      action: 'Generate Triangulation',
      module: 'Triangulation',
      description:
          'Generated development analysis for child ID ${triangulation.childId} with status: ${triangulation.developmentStatus}.',
    );

    return id;
  }

  @override
  Future<List<TriangulationModel>> getHistory(String childId) async {
    if (kIsWeb) {
      final snapshot = await FirebaseFirestore.instance
          .collection('triangulations')
          .where('child_id', isEqualTo: childId)
          .get(const GetOptions(source: Source.server));
      final history = snapshot.docs
          .map(
            (document) => TriangulationModel.fromMap({
              ...document.data(),
              'id': document.data()['id'] ?? int.tryParse(document.id),
            }),
          )
          .toList();
      history.sort((a, b) => b.generatedDate.compareTo(a.generatedDate));
      return history;
    }
    final data = await _dbHelper.getTriangulationHistory(childId);
    return data.map((map) => TriangulationModel.fromMap(map)).toList();
  }

  @override
  Future<Map<String, dynamic>> fetchTriangulationInputs(String childId) async {
    if (kIsWeb) {
      return _fetchCloudInputs(childId);
    }

    final evaluations = await _dbHelper.getLatestEvaluations(childId);
    final feedback = await _dbHelper.getFeedbackByChild(childId);
    final history = await _dbHelper.getChildEvaluationHistory(childId);
    return _buildInputs(
      evaluations: evaluations,
      feedback: feedback,
      history: history,
    );
  }

  Future<Map<String, dynamic>> _fetchCloudInputs(String childId) async {
    // Do not let a denied/missing feedback query erase valid teacher
    // assessments (or the reverse). Each collection is a separate source for
    // the triangulation and should degrade independently.
    List<Map<String, dynamic>> evaluationRecords = const [];
    List<Map<String, dynamic>> feedbackRecords = const [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('evaluations')
          .where('child_id', isEqualTo: childId)
          .get(const GetOptions(source: Source.server));
      evaluationRecords = snapshot.docs
          .map(
            (document) => <String, dynamic>{
              ...document.data(),
              'id': int.tryParse(document.id),
            },
          )
          .toList();
    } catch (_) {
      // The empty state below is intentional only for this source.
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('parent_feedback')
          .where('child_id', isEqualTo: childId)
          .get(const GetOptions(source: Source.server));
      feedbackRecords = snapshot.docs
          .map(
            (document) => <String, dynamic>{
              ...document.data(),
              'id': int.tryParse(document.id),
            },
          )
          .toList();
    } catch (_) {
      // The empty state below is intentional only for this source.
    }

    evaluationRecords.sort(
      (a, b) => _recordDate(
        b,
        'evaluation_date',
      ).compareTo(_recordDate(a, 'evaluation_date')),
    );
    feedbackRecords.sort(
      (a, b) => _recordDate(
        b,
        'submission_date',
      ).compareTo(_recordDate(a, 'submission_date')),
    );

    // One current record per domain is the teacher input; all records stay
    // available as history for trend analysis.
    final latestByDomain = <String, Map<String, dynamic>>{};
    for (final record in evaluationRecords) {
      latestByDomain.putIfAbsent(
        record['domain']?.toString() ?? 'Unspecified domain',
        () => record,
      );
    }
    return _buildInputs(
      evaluations: latestByDomain.values.toList(),
      feedback: feedbackRecords,
      history: evaluationRecords,
    );
  }

  Map<String, dynamic> _buildInputs({
    required List<Map<String, dynamic>> evaluations,
    required List<Map<String, dynamic>> feedback,
    required List<Map<String, dynamic>> history,
  }) {
    String teacherSummary = _generateTeacherSummary(evaluations);
    String parentSummary = _generateParentSummary(feedback);
    String historySummary = _generateHistorySummary(history);

    return {
      'teacher_summary': teacherSummary,
      'parent_summary': parentSummary,
      'history_summary': historySummary,
      'evaluations': evaluations,
      'feedback': feedback,
      'history': history,
    };
  }

  String _generateTeacherSummary(List<Map<String, dynamic>> evaluations) {
    if (evaluations.isEmpty) {
      return 'No assessment records found from teacher.';
    }
    double totalScore = 0;
    final domainDetails = <String>[];
    for (final evaluation in evaluations) {
      final score = (evaluation['score'] as num?)?.toDouble() ?? 0;
      totalScore += score;
      final domain = evaluation['domain']?.toString() ?? 'Unspecified domain';
      final remarks = evaluation['remarks']?.toString().trim() ?? '';
      domainDetails.add(
        '$domain: ${score.toStringAsFixed(score == score.roundToDouble() ? 0 : 1)}/4'
        '${remarks.isEmpty ? '' : ' — $remarks'}',
      );
    }
    final average = totalScore / evaluations.length;
    return 'Latest teacher assessment across ${evaluations.length} domain(s): '
        'average ${average.toStringAsFixed(1)}/4. ${domainDetails.join(' | ')}';
  }

  String _generateParentSummary(List<Map<String, dynamic>> feedback) {
    if (feedback.isEmpty) return 'No parent feedback records found.';
    final details = feedback.map((record) {
      final date = _recordDate(record, 'submission_date');
      final observation = record['parent_observation']?.toString().trim() ?? '';
      final assistance = record['assistance_level']?.toString().trim() ?? '';
      final notes = record['notes']?.toString().trim() ?? '';
      final parts = <String>[
        if (date.isNotEmpty) '[$date]',
        if (observation.isNotEmpty) observation,
        if (assistance.isNotEmpty) 'assistance: $assistance',
        if (notes.isNotEmpty) 'notes: $notes',
      ];
      return parts.isEmpty
          ? 'Parent update with no narrative.'
          : parts.join(' ');
    });
    return 'Parent feedback across ${feedback.length} update(s): '
        '${details.join(' | ')}';
  }

  String _generateHistorySummary(List<Map<String, dynamic>> history) {
    if (history.isEmpty) {
      return 'No historical data available for trend analysis.';
    }
    final dates =
        history
            .map((record) => _recordDate(record, 'evaluation_date'))
            .where((date) => date.isNotEmpty)
            .toList()
          ..sort();
    final firstDate = dates.isEmpty ? 'an unknown date' : dates.first;
    final lastDate = dates.isEmpty ? 'an unknown date' : dates.last;
    final byDomain = <String, List<Map<String, dynamic>>>{};
    for (final record in history) {
      final domain = record['domain']?.toString().trim();
      byDomain
          .putIfAbsent(
            domain == null || domain.isEmpty ? 'Unspecified domain' : domain,
            () => <Map<String, dynamic>>[],
          )
          .add(record);
    }
    final domainTrends = byDomain.entries.map((entry) {
      final records = [...entry.value]
        ..sort(
          (a, b) => _recordDate(
            a,
            'evaluation_date',
          ).compareTo(_recordDate(b, 'evaluation_date')),
        );
      final firstScore = (records.first['score'] as num?)?.toDouble() ?? 0;
      final latestScore = (records.last['score'] as num?)?.toDouble() ?? 0;
      String formatScore(double score) => score == score.roundToDouble()
          ? score.toStringAsFixed(0)
          : score.toStringAsFixed(1);
      return '${entry.key}: ${records.length} record(s), '
          '${formatScore(firstScore)}/4 to ${formatScore(latestScore)}/4';
    });
    return 'Historical teacher records span $firstDate to $lastDate across '
        '${history.length} assessment(s) in ${byDomain.length} domain(s). '
        'Per-domain trend: ${domainTrends.join(' | ')}.';
  }

  String _recordDate(Map<String, dynamic> record, String field) {
    final raw = record[field];
    if (raw is Timestamp) return raw.toDate().toUtc().toIso8601String();
    return raw?.toString() ?? '';
  }
}
