class DashboardStats {
  final int totalChildren;
  final int totalTeachers;
  final int totalParents;
  final int presentToday;
  final int absentToday;
  final int completedEvaluations;
  final int pendingReferrals;

  DashboardStats({
    required this.totalChildren,
    required this.totalTeachers,
    required this.totalParents,
    required this.presentToday,
    required this.absentToday,
    required this.completedEvaluations,
    required this.pendingReferrals,
  });

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    return DashboardStats(
      totalChildren: map['total_children'] ?? 0,
      totalTeachers: map['total_teachers'] ?? 0,
      totalParents: map['total_parents'] ?? 0,
      presentToday: map['present_today'] ?? 0,
      absentToday: map['absent_today'] ?? 0,
      completedEvaluations: map['completed_evaluations'] ?? 0,
      pendingReferrals: map['pending_referrals'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_children': totalChildren,
      'total_teachers': totalTeachers,
      'total_parents': totalParents,
      'present_today': presentToday,
      'absent_today': absentToday,
      'completed_evaluations': completedEvaluations,
      'pending_referrals': pendingReferrals,
    };
  }
}

class AttendanceReportItem {
  final String childId;
  final String childName;
  final int present;
  final int absent;
  final double attendanceRate;

  AttendanceReportItem({
    required this.childId,
    required this.childName,
    required this.present,
    required this.absent,
    required this.attendanceRate,
  });

  factory AttendanceReportItem.fromMap(Map<String, dynamic> map) {
    int present = map['present'] ?? 0;
    int absent = map['absent'] ?? 0;
    int total = present + absent;
    double rate = total > 0 ? (present / total) * 100 : 0.0;
    return AttendanceReportItem(
      childId: map['child_id'] ?? '',
      childName: map['child_name'] ?? '',
      present: present,
      absent: absent,
      attendanceRate: rate,
    );
  }
}

class EvaluationReportItem {
  final String childId;
  final String childName;
  final String domain;
  final int score;
  final String date;
  final String remarks;

  EvaluationReportItem({
    required this.childId,
    required this.childName,
    required this.domain,
    required this.score,
    required this.date,
    required this.remarks,
  });

  factory EvaluationReportItem.fromMap(Map<String, dynamic> map) {
    return EvaluationReportItem(
      childId: map['child_id'] ?? '',
      childName: map['child_name'] ?? '',
      domain: map['domain'] ?? '',
      score: map['score'] ?? 0,
      date: map['evaluation_date'] ?? '',
      remarks: map['remarks'] ?? '',
    );
  }
}

class ReferralReportItem {
  final String childId;
  final String childName;
  final String concern;
  final String referralDate;
  final String followUpDate;
  final String status;

  ReferralReportItem({
    required this.childId,
    required this.childName,
    required this.concern,
    required this.referralDate,
    required this.followUpDate,
    required this.status,
  });

  factory ReferralReportItem.fromMap(Map<String, dynamic> map) {
    return ReferralReportItem(
      childId: map['child_id'] ?? '',
      childName: map['child_name'] ?? '',
      concern: map['concern'] ?? '',
      referralDate: map['referral_date'] ?? '',
      followUpDate: map['follow_up_date'] ?? '',
      status: map['status'] ?? '',
    );
  }
}

class ChildProgressReportItem {
  final String childId;
  final String childName;
  final String domain;
  final int? previousScore;
  final int currentScore;
  final int maxScore;
  final String? developmentStatus;
  final String? triangulatedSummary;

  ChildProgressReportItem({
    required this.childId,
    required this.childName,
    required this.domain,
    this.previousScore,
    required this.currentScore,
    this.maxScore = 20,
    this.developmentStatus,
    this.triangulatedSummary,
  });

  factory ChildProgressReportItem.fromMap(Map<String, dynamic> map) {
    return ChildProgressReportItem(
      childId: map['child_id'] ?? '',
      childName: map['child_name'] ?? '',
      domain: map['domain'] ?? '',
      previousScore: map['previous_score'],
      currentScore: map['current_score'] ?? 0,
      maxScore: map['max_score'] ?? 20,
      developmentStatus: map['development_status'],
      triangulatedSummary: map['triangulated_summary'],
    );
  }
}
