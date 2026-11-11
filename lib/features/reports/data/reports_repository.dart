import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/database_helper.dart';
import '../../../data/repositories/file_upload_repository.dart';
import '../../../core/config/supabase_config.dart';
import '../domain/reports_model.dart';

abstract class ReportsRepository {
  Future<DashboardStats> getDashboardStats();
  Future<List<AttendanceReportItem>> getAttendanceReport();
  Future<List<EvaluationReportItem>> getEvaluationReport();
  Future<List<ReferralReportItem>> getReferralReport();
  Future<List<ChildProgressReportItem>> getChildProgressReport();
  Future<String?> uploadPdfReport(
    String reportId,
    Uint8List pdfBytes,
    String fileName,
  );
}

class ReportsRepositoryImpl implements ReportsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FileUploadRepository _fileUploadRepo = FileUploadRepository();

  @override
  Future<DashboardStats> getDashboardStats() async {
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (kIsWeb) {
      final queries = await Future.wait([
        _firestore.collection('children').get(),
        _firestore
            .collection('referrals')
            .where('status', isEqualTo: 'Pending')
            .get(),
        _firestore.collection('evaluations').get(),
        _firestore
            .collection('attendance_events')
            .where('attendance_date', isEqualTo: today)
            .get(),
        _firestore.collection('users').get(),
      ]);
      final children = queries[0];
      final referrals = queries[1];
      final evaluations = queries[2];
      final attendance = queries[3];
      final users = queries[4];

      return DashboardStats(
        totalChildren: children.size,
        totalTeachers: users.docs
            .where((d) => d.data()['role'] == 'teacher')
            .length,
        totalParents: users.docs
            .where((d) => d.data()['role'] == 'parent')
            .length,
        presentToday: attendance.docs
            .where((d) => d.data()['status'] == 'Present')
            .length,
        absentToday: attendance.docs
            .where((d) => d.data()['status'] == 'Absent')
            .length,
        completedEvaluations: evaluations.docs
            .map((d) => d.data()['child_id'])
            .toSet()
            .length,
        pendingReferrals: referrals.size,
      );
    } else {
      final data = await _dbHelper.getDashboardStats(today);
      return DashboardStats.fromMap(data);
    }
  }

  @override
  Future<List<AttendanceReportItem>> getAttendanceReport() async {
    if (kIsWeb) {
      final queries = await Future.wait([
        _firestore.collection('children').get(),
        // AttendanceRepository syncs to attendance_events. Reading the old
        // `attendance` collection here left web reports empty.
        _firestore.collection('attendance_events').get(),
      ]);
      final children = queries[0];
      final attendance = queries[1];

      List<AttendanceReportItem> items = [];
      for (var doc in children.docs) {
        final data = doc.data();
        final cid = (data['child_id'] ?? doc.id).toString();
        final childAttendance = attendance.docs.where(
          (d) => d.data()['child_id'] == cid,
        );
        final present = childAttendance
            .where((d) => d.data()['status'] == 'Present')
            .length;
        final absent = childAttendance
            .where((d) => d.data()['status'] == 'Absent')
            .length;
        final total = present + absent;

        items.add(
          AttendanceReportItem(
            childId: cid,
            childName: _childName(data),
            present: present,
            absent: absent,
            attendanceRate: total > 0 ? (present / total) * 100 : 0.0,
          ),
        );
      }
      return items;
    } else {
      final data = await _dbHelper.getAttendanceReport();
      return data.map((e) => AttendanceReportItem.fromMap(e)).toList();
    }
  }

  @override
  Future<List<EvaluationReportItem>> getEvaluationReport() async {
    if (kIsWeb) {
      final queries = await Future.wait([
        _firestore.collection('children').get(),
        _firestore.collection('evaluations').get(),
      ]);
      final children = queries[0];
      final evaluations = queries[1];

      final childrenById = _childrenById(children.docs);
      final result = <EvaluationReportItem>[];
      for (var doc in evaluations.docs) {
        final data = doc.data();
        final childId = data['child_id']?.toString() ?? '';
        final childData = childrenById[childId];
        if (childId.isEmpty || childData == null) continue;
        result.add(
          EvaluationReportItem(
            childId: childId,
            childName: _childName(childData),
            domain: data['domain']?.toString() ?? 'Unspecified domain',
            score: (data['score'] as num?)?.toInt() ?? 0,
            date: data['evaluation_date'] ?? '',
            remarks: data['remarks'] ?? '',
          ),
        );
      }
      return result;
    } else {
      final data = await _dbHelper.getEvaluationReport();
      return data.map((e) => EvaluationReportItem.fromMap(e)).toList();
    }
  }

  @override
  Future<List<ReferralReportItem>> getReferralReport() async {
    if (kIsWeb) {
      final queries = await Future.wait([
        _firestore.collection('children').get(),
        _firestore.collection('referrals').get(),
      ]);
      final children = queries[0];
      final referrals = queries[1];

      final childrenById = _childrenById(children.docs);
      final result = <ReferralReportItem>[];
      for (var doc in referrals.docs) {
        final data = doc.data();
        final childId = data['child_id']?.toString() ?? '';
        final childData = childrenById[childId];
        if (childId.isEmpty || childData == null) continue;
        result.add(
          ReferralReportItem(
            childId: childId,
            childName: _childName(childData),
            concern: data['concern'] ?? '',
            referralDate: data['referral_date'] ?? '',
            followUpDate: data['follow_up_date'] ?? '',
            status: data['status'] ?? '',
          ),
        );
      }
      return result;
    } else {
      final data = await _dbHelper.getReferralReport();
      return data.map((e) => ReferralReportItem.fromMap(e)).toList();
    }
  }

  @override
  Future<List<ChildProgressReportItem>> getChildProgressReport() async {
    if (kIsWeb) {
      final queries = await Future.wait([
        _firestore.collection('children').get(),
        _firestore.collection('evaluations').get(),
        _firestore.collection('triangulations').get(),
      ]);
      final children = queries[0];
      final evaluations = queries[1];
      final triangulations = queries[2];
      final childrenById = _childrenById(children.docs);

      final latestTriangulationByChild = <String, Map<String, dynamic>>{};
      for (final document in triangulations.docs) {
        final record = document.data();
        final childId = record['child_id']?.toString() ?? '';
        if (childId.isEmpty) continue;
        final existing = latestTriangulationByChild[childId];
        if (existing == null ||
            _recordDate(
              record,
              'generated_date',
            ).isAfter(_recordDate(existing, 'generated_date'))) {
          latestTriangulationByChild[childId] = record;
        }
      }

      final evaluationsByChildDomain = <String, List<Map<String, dynamic>>>{};
      for (final document in evaluations.docs) {
        final record = document.data();
        final childId = record['child_id']?.toString() ?? '';
        final domain = record['domain']?.toString().trim() ?? '';
        if (childId.isEmpty ||
            domain.isEmpty ||
            !childrenById.containsKey(childId)) {
          continue;
        }
        evaluationsByChildDomain
            .putIfAbsent(
              '$childId\u0000$domain',
              () => <Map<String, dynamic>>[],
            )
            .add(record);
      }

      final items = <ChildProgressReportItem>[];
      for (final entry in evaluationsByChildDomain.entries) {
        final records = entry.value
          ..sort(
            (a, b) => _recordDate(
              a,
              'evaluation_date',
            ).compareTo(_recordDate(b, 'evaluation_date')),
          );
        final latest = records.last;
        final splitKey = entry.key.split('\u0000');
        final childId = splitKey.first;
        final triangulation = latestTriangulationByChild[childId];
        items.add(
          ChildProgressReportItem(
            childId: childId,
            childName: _childName(childrenById[childId]!),
            domain: splitKey.last,
            previousScore: records.length > 1
                ? (records[records.length - 2]['score'] as num?)?.toInt()
                : null,
            currentScore: (latest['score'] as num?)?.toInt() ?? 0,
            maxScore: 4,
            developmentStatus: triangulation?['development_status']?.toString(),
            triangulatedSummary: triangulation?['triangulated_summary']
                ?.toString(),
          ),
        );
      }
      items.sort((a, b) {
        final childComparison = a.childName.compareTo(b.childName);
        return childComparison == 0
            ? a.domain.compareTo(b.domain)
            : childComparison;
      });
      return items;
    } else {
      final data = await _dbHelper.getChildProgressReport();
      return data.map((e) => ChildProgressReportItem.fromMap(e)).toList();
    }
  }

  Map<String, Map<String, dynamic>> _childrenById(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> children,
  ) {
    return {
      for (final child in children)
        (child.data()['child_id'] ?? child.id).toString(): child.data(),
    };
  }

  String _childName(Map<String, dynamic> data) {
    return '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
  }

  DateTime _recordDate(Map<String, dynamic> record, String field) {
    final value = record[field];
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString().replaceFirst(' ', 'T') ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Future<String?> uploadPdfReport(
    String reportId,
    Uint8List pdfBytes,
    String fileName,
  ) async {
    return await _fileUploadRepo.uploadBytes(
      bucket: SupabaseConfig.pdfReports,
      entityId: reportId,
      category: SupabaseConfig.pdfReportsCategory,
      bytes: pdfBytes,
      fileName: fileName,
      contentType: 'application/pdf',
      docCollection: 'reports',
      urlFieldName: 'pdf_url',
    );
  }
}
