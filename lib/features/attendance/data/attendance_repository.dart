import '../../../core/database/database_helper.dart';
import '../domain/attendance_model.dart';

abstract class AttendanceRepository {
  Future<int> addAttendance(AttendanceModel attendance);
  Future<List<Map<String, dynamic>>> getHistory(String childId);
  Future<List<Map<String, dynamic>>> getSummary(String date);
}

class AttendanceRepositoryImpl implements AttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<int> addAttendance(AttendanceModel attendance) async {
    return await _dbHelper.insertAttendance(attendance.toMap());
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory(String childId) async {
    return await _dbHelper.getChildAttendanceHistory(childId);
  }

  @override
  Future<List<Map<String, dynamic>>> getSummary(String date) async {
    return await _dbHelper.getAttendanceSummaryByDate(date);
  }
}
