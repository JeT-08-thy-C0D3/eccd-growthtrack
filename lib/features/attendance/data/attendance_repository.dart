import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../domain/attendance_model.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/utils/audit_logger.dart';

abstract class AttendanceRepository {
  Future<int> addAttendance(AttendanceModel attendance);
  Future<List<Map<String, dynamic>>> getHistory(String childId);
  Future<List<Map<String, dynamic>>> getSummary(String date);
}

class AttendanceRepositoryImpl implements AttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  Future<int> addAttendance(AttendanceModel attendance) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final newAttendance = attendance.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    // 1. Save Locally
    final id = await _local.saveRecord('attendance', newAttendance.toMap());

    // 2. Sync to Cloud if online
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('attendance', id.toString(), newAttendance.toMap());
        await _local.markAsSynced('attendance', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    // 3. Log Action
    await AuditLogger.log(
      action: 'Record Attendance',
      module: 'Attendance',
      description: 'Recorded attendance for child ID ${attendance.childId} as ${attendance.status}.',
    );

    return id;
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
