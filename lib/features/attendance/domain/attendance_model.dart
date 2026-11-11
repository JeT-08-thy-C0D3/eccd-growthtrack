class AttendanceModel {
  final int? id;
  final String childId;
  final String attendanceDate;
  final String attendanceTime;
  final String status;
  final String updatedAt;
  final bool isSynced;

  /// Stable local/cloud id. Old rows do not have one and remain readable.
  final String? attendanceEventId;

  /// `manual` or `rfid`; legacy records are treated as manual.
  final String attendanceMethod;

  /// The original accepted event instant in UTC, never replaced by sync time.
  final String? eventTimestampUtc;

  AttendanceModel({
    this.id,
    required this.childId,
    required this.attendanceDate,
    required this.attendanceTime,
    required this.status,
    required this.updatedAt,
    this.isSynced = false,
    this.attendanceEventId,
    this.attendanceMethod = 'manual',
    this.eventTimestampUtc,
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
      'attendance_event_id': attendanceEventId,
      'attendance_method': attendanceMethod,
      'event_timestamp_utc': eventTimestampUtc,
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
      attendanceEventId:
          map['attendance_event_id'] as String? ??
          map['attendanceEventId'] as String?,
      attendanceMethod:
          map['attendance_method'] as String? ??
          map['attendanceMethod'] as String? ??
          'manual',
      eventTimestampUtc:
          map['event_timestamp_utc'] as String? ??
          map['eventTimestampUtc'] as String?,
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
    String? attendanceEventId,
    String? attendanceMethod,
    String? eventTimestampUtc,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      attendanceTime: attendanceTime ?? this.attendanceTime,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      attendanceEventId: attendanceEventId ?? this.attendanceEventId,
      attendanceMethod: attendanceMethod ?? this.attendanceMethod,
      eventTimestampUtc: eventTimestampUtc ?? this.eventTimestampUtc,
    );
  }
}
