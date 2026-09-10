import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../domain/reports_model.dart';

abstract class ReportsRepository {
  Future<DashboardStats> getDashboardStats();
  Future<List<AttendanceReportItem>> getAttendanceReport();
  Future<List<EvaluationReportItem>> getEvaluationReport();
  Future<List<ReferralReportItem>> getReferralReport();
  Future<List<ChildProgressReportItem>> getChildProgressReport();
}

class ReportsRepositoryImpl implements ReportsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<DashboardStats> getDashboardStats() async {
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = await _dbHelper.getDashboardStats(today);
    return DashboardStats.fromMap(data);
  }

  @override
  Future<List<AttendanceReportItem>> getAttendanceReport() async {
    final data = await _dbHelper.getAttendanceReport();
    return data.map((e) => AttendanceReportItem.fromMap(e)).toList();
  }

  @override
  Future<List<EvaluationReportItem>> getEvaluationReport() async {
    final data = await _dbHelper.getEvaluationReport();
    return data.map((e) => EvaluationReportItem.fromMap(e)).toList();
  }

  @override
  Future<List<ReferralReportItem>> getReferralReport() async {
    final data = await _dbHelper.getReferralReport();
    return data.map((e) => ReferralReportItem.fromMap(e)).toList();
  }

  @override
  Future<List<ChildProgressReportItem>> getChildProgressReport() async {
    final data = await _dbHelper.getChildProgressReport();
    return data.map((e) => ChildProgressReportItem.fromMap(e)).toList();
  }
}
