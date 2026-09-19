class ActivityModel {
  final int? id;
  final String childId;
  final String activityTitle;
  final String instructions;
  final String dueDate;
  final String assignedBy;
  final String createdDate;
  final String status; // Assigned, Completed, Overdue
  final String updatedAt;
  final bool isSynced;

  ActivityModel({
    this.id,
    required this.childId,
    required this.activityTitle,
    required this.instructions,
    required this.dueDate,
    required this.assignedBy,
    required this.createdDate,
    required this.status,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'activity_title': activityTitle,
      'instructions': instructions,
      'due_date': dueDate,
      'assigned_by': assignedBy,
      'created_date': createdDate,
      'status': status,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    return ActivityModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      activityTitle: map['activity_title'] ?? '',
      instructions: map['instructions'] ?? '',
      dueDate: map['due_date'] ?? '',
      assignedBy: map['assigned_by'] ?? '',
      createdDate: map['created_date'] ?? '',
      status: map['status'] ?? 'Assigned',
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  ActivityModel copyWith({
    int? id,
    String? childId,
    String? activityTitle,
    String? instructions,
    String? dueDate,
    String? assignedBy,
    String? createdDate,
    String? status,
    String? updatedAt,
    bool? isSynced,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      activityTitle: activityTitle ?? this.activityTitle,
      instructions: instructions ?? this.instructions,
      dueDate: dueDate ?? this.dueDate,
      assignedBy: assignedBy ?? this.assignedBy,
      createdDate: createdDate ?? this.createdDate,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
