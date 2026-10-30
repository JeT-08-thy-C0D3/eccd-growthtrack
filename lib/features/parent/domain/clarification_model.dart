import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ClarificationModel {
  final int? id;
  final String childId;
  final int parentId;
  final int? teacherId;
  final String category; // Assessment, Home Activity, Referral, General Concern
  final String message;
  final String? response;
  final String status; // Pending, Responded
  final String createdAt;
  final String updatedAt;
  final bool isSynced;

  ClarificationModel({
    this.id,
    required this.childId,
    required this.parentId,
    this.teacherId,
    this.category = 'General Concern',
    required this.message,
    this.response,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'parent_id': parentId,
      'teacher_id': teacherId,
      'category': category,
      'message': message,
      'response': response,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ClarificationModel.fromMap(Map<String, dynamic> map) {
    final serverCreated = _serverUtcText(map['server_created_at']);
    final serverUpdated = _serverUtcText(map['server_updated_at']);
    return ClarificationModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      parentId: map['parent_id'] ?? 0,
      teacherId: map['teacher_id'],
      category: map['category'] ?? 'General Concern',
      message: map['message'] ?? '',
      response: map['response'],
      status: map['status'] ?? 'Pending',
      createdAt: serverCreated ?? map['created_at'] ?? '',
      updatedAt: serverUpdated ?? map['updated_at'] ?? '',
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  static String? _serverUtcText(dynamic value) {
    if (value is! Timestamp) return null;
    return DateFormat('yyyy-MM-dd HH:mm:ss \'UTC\'')
        .format(value.toDate().toUtc());
  }

  ClarificationModel copyWith({
    int? id,
    String? childId,
    int? parentId,
    int? teacherId,
    String? category,
    String? message,
    String? response,
    String? status,
    String? createdAt,
    String? updatedAt,
    bool? isSynced,
  }) {
    return ClarificationModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      parentId: parentId ?? this.parentId,
      teacherId: teacherId ?? this.teacherId,
      category: category ?? this.category,
      message: message ?? this.message,
      response: response ?? this.response,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
