import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogModel {
  final String id;
  final String userId;
  final String action;
  final String module;
  final String description;
  final DateTime timestamp;

  AuditLogModel({
    required this.id,
    required this.userId,
    required this.action,
    required this.module,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'module': module,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditLogModel.fromMap(Map<String, dynamic> map, String docId) {
    return AuditLogModel(
      id: docId,
      userId: map['user_id'] ?? '',
      action: map['action'] ?? '',
      module: map['module'] ?? '',
      description: map['description'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}
