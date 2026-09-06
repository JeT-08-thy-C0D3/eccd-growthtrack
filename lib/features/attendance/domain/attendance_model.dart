class AttendanceModel {
  final int? id;
  final String childId;
  final String attendanceDate;
  final String attendanceTime;
  final String status;

  AttendanceModel({
    this.id,
    required this.childId,
    required this.attendanceDate,
    required this.attendanceTime,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'attendance_date': attendanceDate,
      'attendance_time': attendanceTime,
      'status': status,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'],
      childId: map['child_id'],
      attendanceDate: map['attendance_date'],
      attendanceTime: map['attendance_time'],
      status: map['status'],
    );
  }
}
