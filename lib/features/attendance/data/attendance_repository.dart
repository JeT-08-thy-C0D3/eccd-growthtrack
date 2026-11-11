import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../domain/attendance_model.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/utils/audit_logger.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

class AttendanceSaveResult {
  const AttendanceSaveResult({
    required this.attendance,
    required this.localId,
    this.alreadyPresent = false,
  });
  final AttendanceModel attendance;
  final int localId;
  final bool alreadyPresent;
}

abstract class AttendanceRepository {
  Future<int> addAttendance(AttendanceModel attendance);
  Future<List<Map<String, dynamic>>> getHistory(String childId);
  Future<List<Map<String, dynamic>>> getSummary(String date);
  Future<AttendanceSaveResult> recordAttendance(AttendanceModel attendance);
}

class AttendanceRepositoryImpl implements AttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  Future<int> addAttendance(AttendanceModel attendance) async {
    final saved = await recordAttendance(attendance);
    return saved.localId;
  }

  /// Single local-first write path used by both RFID and manual attendance.
  /// Its stable event id makes retry/sync delivery idempotent and leaves the
  /// accepted scan timestamp unchanged.
  @override
  Future<AttendanceSaveResult> recordAttendance(
    AttendanceModel attendance,
  ) async {
    final originalUtc =
        attendance.eventTimestampUtc ??
        DateTime.now().toUtc().toIso8601String();
    final stableEventId =
        attendance.attendanceEventId ??
        'attendance-${attendance.childId}-${attendance.attendanceDate}-${attendance.status.toLowerCase()}';
    final newAttendance = attendance.copyWith(
      attendanceEventId: stableEventId,
      eventTimestampUtc: originalUtc,
      updatedAt: attendance.updatedAt.isEmpty
          ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())
          : attendance.updatedAt,
      isSynced: false,
    );

    if (!kIsWeb && attendance.status == 'Present') {
      final existing = await _dbHelper.getPresentAttendanceForSchoolDay(
        attendance.childId,
        attendance.attendanceDate,
      );
      if (existing != null) {
        return AttendanceSaveResult(
          attendance: AttendanceModel.fromMap(existing),
          localId: existing['id'] as int? ?? 0,
          alreadyPresent: true,
        );
      }
    }

    // 1. Save Locally
    final id = await _local.saveRecord('attendance', newAttendance.toMap());

    // 2. Sync to Cloud if online
    // Browser builds write directly to Firestore. `connectivity_plus` may
    // report no transport in Chrome even while Firebase is available, which
    // left valid RFID/manual events local-only and made the parent dashboard
    // look as if there was no attendance record.
    if (kIsWeb || await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord(
          'attendance_events',
          stableEventId,
          newAttendance.toMap(),
        );
        if (!kIsWeb) {
          await _local.markAsSynced('attendance', stableEventId);
        }
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    // 3. Log Action
    await AuditLogger.log(
      action: 'Record Attendance',
      module: 'Attendance',
      description:
          'Recorded ${newAttendance.attendanceMethod} attendance for child ID ${attendance.childId} as ${attendance.status}; event $stableEventId.',
    );

    return AttendanceSaveResult(attendance: newAttendance, localId: id);
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
