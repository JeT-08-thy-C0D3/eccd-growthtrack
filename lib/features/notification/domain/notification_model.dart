class NotificationModel {
  final int? id;
  final String? docId;
  final String recipientUid;
  final String childId;
  final String childName;
  final String type; // home_activity, development_summary, referral, clarification_response
  final String title;
  final String body;
  final String? referenceId;
  final bool isRead;
  final String createdAt;
  final bool isSynced;

  NotificationModel({
    this.id,
    this.docId,
    required this.recipientUid,
    required this.childId,
    required this.childName,
    required this.type,
    required this.title,
    required this.body,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doc_id': docId,
      'recipient_uid': recipientUid,
      'child_id': childId,
      'child_name': childName,
      'type': type,
      'title': title,
      'body': body,
      'reference_id': referenceId,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final rawIsRead = map['is_read'];
    bool read = false;
    if (rawIsRead is bool) {
      read = rawIsRead;
    } else if (rawIsRead is int) {
      read = rawIsRead == 1;
    }

    return NotificationModel(
      id: map['id'] as int?,
      docId: map['doc_id'] as String? ?? map['id']?.toString(),
      recipientUid: map['recipient_uid'] as String? ?? '',
      childId: map['child_id'] as String? ?? '',
      childName: map['child_name'] as String? ?? '',
      type: map['type'] as String? ?? 'general',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      referenceId: map['reference_id'] as String?,
      isRead: read,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  NotificationModel copyWith({
    int? id,
    String? docId,
    String? recipientUid,
    String? childId,
    String? childName,
    String? type,
    String? title,
    String? body,
    String? referenceId,
    bool? isRead,
    String? createdAt,
    bool? isSynced,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      docId: docId ?? this.docId,
      recipientUid: recipientUid ?? this.recipientUid,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      referenceId: referenceId ?? this.referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
