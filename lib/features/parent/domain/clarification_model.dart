class ClarificationModel {
  final int? id;
  final String childId;
  final int parentId;
  final int? teacherId;
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
      'message': message,
      'response': response,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ClarificationModel.fromMap(Map<String, dynamic> map) {
    return ClarificationModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      parentId: map['parent_id'] ?? 0,
      teacherId: map['teacher_id'],
      message: map['message'] ?? '',
      response: map['response'],
      status: map['status'] ?? 'Pending',
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  ClarificationModel copyWith({
    int? id,
    String? childId,
    int? parentId,
    int? teacherId,
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
      message: message ?? this.message,
      response: response ?? this.response,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
