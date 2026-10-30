import 'package:cloud_firestore/cloud_firestore.dart';

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
      if (rawTime is Timestamp) {
        parsedTimestamp = rawTime.toDate().toUtc();
      } else if (rawTime is DateTime) {
        parsedTimestamp = rawTime.toUtc();
      } else if (rawTime is String) {
        parsedTimestamp = DateTime.parse(rawTime).toUtc();
      } else {
        // A just-written server timestamp can be null in the first snapshot.
        // Do not substitute the device clock while waiting for Firebase.
        parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
    } catch (_) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    return AuditLogModel(
      id: docId,
      action: map['action'] as String? ?? 'General Action',
      performedBy:
          map['performed_by'] as String? ??
          map['user_id'] as String? ??
          'System/Anonymous',
      targetRecord:
          map['target_record'] as String? ??
          map['description'] as String? ??
          map['module'] as String? ??
          'N/A',
      timestamp: parsedTimestamp,
    );
  }
}
