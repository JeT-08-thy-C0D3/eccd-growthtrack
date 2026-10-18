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
  Future<String?> uploadPdfReport(String reportId, Uint8List pdfBytes, String fileName);
}

class ReportsRepositoryImpl implements ReportsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FileUploadRepository _fileUploadRepo = FileUploadRepository();

  @override
  Future<DashboardStats> getDashboardStats() async {
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (kIsWeb) {
      final children = await _firestore.collection('children').get();
      final referrals = await _firestore.collection('referrals').where('status', isEqualTo: 'Pending').get();
      final evaluations = await _firestore.collection('evaluations').get();
      final attendance = await _firestore.collection('attendance').where('attendance_date', isEqualTo: today).get();
      final users = await _firestore.collection('users').get();

      return DashboardStats(
        totalChildren: children.size,
        totalTeachers: users.docs.where((d) => d.data()['role'] == 'teacher').length,
        totalParents: users.docs.where((d) => d.data()['role'] == 'parent').length,
        presentToday: attendance.docs.where((d) => d.data()['status'] == 'Present').length,
        absentToday: attendance.docs.where((d) => d.data()['status'] == 'Absent').length,
        completedEvaluations: evaluations.docs.map((d) => d.data()['child_id']).toSet().length,
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
      final children = await _firestore.collection('children').get();
      final attendance = await _firestore.collection('attendance').get();
      
      List<AttendanceReportItem> items = [];
      for (var doc in children.docs) {
        final data = doc.data();
        final cid = data['child_id'];
        final childAttendance = attendance.docs.where((d) => d.data()['child_id'] == cid);
        final present = childAttendance.where((d) => d.data()['status'] == 'Present').length;
        final absent = childAttendance.where((d) => d.data()['status'] == 'Absent').length;
        final total = present + absent;

        items.add(AttendanceReportItem(
          childId: cid,
          childName: "${data['first_name']} ${data['last_name']}",
          present: present,
          absent: absent,
          attendanceRate: total > 0 ? (present / total) * 100 : 0.0,
        ));
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
      final children = await _firestore.collection('children').get();
      final evaluations = await _firestore.collection('evaluations').get();
      
      List<EvaluationReportItem> result = [];
      for (var doc in evaluations.docs) {
        final data = doc.data();
        final childDoc = children.docs.firstWhere((c) => c.data()['child_id'] == data['child_id']);
        final childData = childDoc.data();
        result.add(EvaluationReportItem(
          childId: data['child_id'],
          childName: "${childData['first_name']} ${childData['last_name']}",
          domain: data['domain'],
          score: data['score'] ?? 0,
          date: data['evaluation_date'] ?? '',
          remarks: data['remarks'] ?? '',
        ));
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
      final children = await _firestore.collection('children').get();
      final referrals = await _firestore.collection('referrals').get();
      
      List<ReferralReportItem> result = [];
      for (var doc in referrals.docs) {
        final data = doc.data();
        final childDoc = children.docs.firstWhere((c) => c.data()['child_id'] == data['child_id']);
        final childData = childDoc.data();
        result.add(ReferralReportItem(
          childId: data['child_id'],
          childName: "${childData['first_name']} ${childData['last_name']}",
          concern: data['concern'] ?? '',
          referralDate: data['referral_date'] ?? '',
          followUpDate: data['follow_up_date'] ?? '',
          status: data['status'] ?? '',
        ));
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
      return []; 
    } else {
      final data = await _dbHelper.getChildProgressReport();
      return data.map((e) => ChildProgressReportItem.fromMap(e)).toList();
    }
  }

  @override
  Future<String?> uploadPdfReport(String reportId, Uint8List pdfBytes, String fileName) async {
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
