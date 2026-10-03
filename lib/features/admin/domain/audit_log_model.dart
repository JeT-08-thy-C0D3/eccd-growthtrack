class AuditLogModel {
  final String id;
  final String action;
  final String performedBy;
  final String targetRecord;
  final DateTime timestamp;

  AuditLogModel({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.targetRecord,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'performed_by': performedBy,
      'target_record': targetRecord,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditLogModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedTimestamp;
    try {
      final rawTime = map['timestamp'];
      if (rawTime is String) {
        parsedTimestamp = DateTime.parse(rawTime);
      } else {
        parsedTimestamp = DateTime.now();
      }
    } catch (_) {
      parsedTimestamp = DateTime.now();
    }

    return AuditLogModel(
      id: docId,
      action: map['action'] as String? ?? 'General Action',
      performedBy: map['performed_by'] as String? ?? map['user_id'] as String? ?? 'System/Anonymous',
      targetRecord: map['target_record'] as String? ?? map['description'] as String? ?? map['module'] as String? ?? 'N/A',
      timestamp: parsedTimestamp,
    );
  }
}
