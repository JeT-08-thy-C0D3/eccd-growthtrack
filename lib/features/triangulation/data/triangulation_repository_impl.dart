import 'package:intl/intl.dart';
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
    final newTri = triangulation.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    final id = await _local.saveRecord('triangulations', newTri.toMap());
    
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('triangulations', id.toString(), newTri.toMap());
        await _local.markAsSynced('triangulations', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    await AuditLogger.log(
      action: 'Generate Triangulation',
      module: 'Triangulation',
      description: 'Generated development analysis for child ID ${triangulation.childId} with status: ${triangulation.developmentStatus}.',
    );

    return id;
  }

  @override
  Future<List<TriangulationModel>> getHistory(String childId) async {
    final data = await _dbHelper.getTriangulationHistory(childId);
    return data.map((map) => TriangulationModel.fromMap(map)).toList();
  }

  @override
  Future<Map<String, dynamic>> fetchTriangulationInputs(String childId) async {
    final evaluations = await _dbHelper.getLatestEvaluations(childId);
    final feedback = await _dbHelper.getFeedbackByChild(childId);
    final history = await _dbHelper.getChildEvaluationHistory(childId);

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
    if (evaluations.isEmpty) return 'No assessment records found from teacher.';
    double totalScore = 0;
    for (var e in evaluations) {
      totalScore += (e['score'] as int);
    }
    double avg = totalScore / evaluations.length;
    return 'Based on ${evaluations.length} domains, the teacher reports an average developmental score of ${avg.toStringAsFixed(1)}.';
  }

  String _generateParentSummary(List<Map<String, dynamic>> feedback) {
    if (feedback.isEmpty) return 'No parent feedback records found.';
    return 'Parent has provided ${feedback.length} updates. Latest: "${feedback.first['parent_observation']}"';
  }

  String _generateHistorySummary(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return 'No historical data available for trend analysis.';
    return 'Historical records spanning back to ${history.last['evaluation_date']} show progress across ${history.length} assessment sessions.';
  }
}
