class ActivityModel {
  final int? id;
  final String childId;
  final String activityTitle;
  final String instructions;
  final String dueDate;
  final String assignedBy;
  final String createdDate;
  final String status; // Assigned, Completed, Overdue

  ActivityModel({
    this.id,
    required this.childId,
    required this.activityTitle,
    required this.instructions,
    required this.dueDate,
    required this.assignedBy,
    required this.createdDate,
    required this.status,
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
    };
  }

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    return ActivityModel(
      id: map['id'],
      childId: map['child_id'],
      activityTitle: map['activity_title'],
      instructions: map['instructions'],
      dueDate: map['due_date'],
      assignedBy: map['assigned_by'],
      createdDate: map['created_date'],
      status: map['status'],
    );
  }
}
