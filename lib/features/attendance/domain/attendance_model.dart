class AttendanceModel {
  final int? id;
  final String childId;
  final String attendanceDate;
  final String attendanceTime;
  final String status;
  final String updatedAt;
  final bool isSynced;

  AttendanceModel({
    this.id,
    required this.childId,
    required this.attendanceDate,
    required this.attendanceTime,
    required this.status,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'attendance_date': attendanceDate,
      'attendance_time': attendanceTime,
      'status': status,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      attendanceDate: map['attendance_date'] ?? '',
      attendanceTime: map['attendance_time'] ?? '',
      status: map['status'] ?? '',
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  AttendanceModel copyWith({
    int? id,
    String? childId,
    String? attendanceDate,
    String? attendanceTime,
    String? status,
    String? updatedAt,
    bool? isSynced,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      attendanceTime: attendanceTime ?? this.attendanceTime,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
