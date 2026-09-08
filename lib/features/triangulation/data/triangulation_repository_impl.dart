import '../../../core/database/database_helper.dart';
import '../domain/triangulation_model.dart';
import '../domain/triangulation_repository.dart';

class TriangulationRepositoryImpl implements TriangulationRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<int> saveTriangulation(TriangulationModel triangulation) async {
    return await _dbHelper.insertTriangulation(triangulation.toMap());
  }

  @override
  Future<List<TriangulationModel>> getHistory(String childId) async {
    final data = await _dbHelper.getTriangulationHistory(childId);
    return data.map((map) => TriangulationModel.fromMap(map)).toList();
  }

  @override
  Future<Map<String, dynamic>> fetchTriangulationInputs(String childId) async {
    // 1. Fetch Teacher Assessments (Evaluations)
    final evaluations = await _dbHelper.getLatestEvaluations(childId);
    
    // 2. Fetch Parent Feedback
    final feedback = await _dbHelper.getFeedbackByChild(childId);
    
    // 3. Fetch Historical Trend (Evaluation History)
    final history = await _dbHelper.getChildEvaluationHistory(childId);

    // Prepare Summaries (This is where future AI logic would reside)
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
    return 'Based on ${evaluations.length} domains, the teacher reports an average developmental score of ${avg.toStringAsFixed(1)}. Top areas: ${evaluations.first['domain']}.';
  }

  String _generateParentSummary(List<Map<String, dynamic>> feedback) {
    if (feedback.isEmpty) return 'No parent feedback records found.';
    return 'Parent has provided ${feedback.length} updates. Latest: "${feedback.first['message']}"';
  }

  String _generateHistorySummary(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return 'No historical data available for trend analysis.';
    return 'Historical records spanning back to ${history.last['evaluation_date']} show progress across ${history.length} assessment sessions.';
  }
}
