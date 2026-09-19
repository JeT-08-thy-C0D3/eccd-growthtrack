class ReferralModel {
  final int? id;
  final String childId;
  final String concern;
  final String description;
  final String referralDate;
  final String followUpDate;
  final String status; // Pending, Referred, For Follow-Up, Completed, Closed
  final String? followUpNotes;
  final String updatedAt;
  final bool isSynced;

  ReferralModel({
    this.id,
    required this.childId,
    required this.concern,
    required this.description,
    required this.referralDate,
    required this.followUpDate,
    required this.status,
    this.followUpNotes,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'concern': concern,
      'description': description,
      'referral_date': referralDate,
      'follow_up_date': followUpDate,
      'status': status,
      'follow_up_notes': followUpNotes,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ReferralModel.fromMap(Map<String, dynamic> map) {
    return ReferralModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      concern: map['concern'] ?? '',
      description: map['description'] ?? '',
      referralDate: map['referral_date'] ?? '',
      followUpDate: map['follow_up_date'] ?? '',
      status: map['status'] ?? 'Pending',
      followUpNotes: map['follow_up_notes'],
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  ReferralModel copyWith({
    int? id,
    String? childId,
    String? concern,
    String? description,
    String? referralDate,
    String? followUpDate,
    String? status,
    String? followUpNotes,
    String? updatedAt,
    bool? isSynced,
  }) {
    return ReferralModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      concern: concern ?? this.concern,
      description: description ?? this.description,
      referralDate: referralDate ?? this.referralDate,
      followUpDate: followUpDate ?? this.followUpDate,
      status: status ?? this.status,
      followUpNotes: followUpNotes ?? this.followUpNotes,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
