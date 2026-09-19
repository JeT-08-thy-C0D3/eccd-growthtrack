class EvaluationModel {
  final int? id;
  final String childId;
  final String domain;
  final int score;
  final String remarks;
  final String evaluationDate;
  final String updatedAt;
  final bool isSynced;

  EvaluationModel({
    this.id,
    required this.childId,
    required this.domain,
    required this.score,
    required this.remarks,
    required this.evaluationDate,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'domain': domain,
      'score': score,
      'remarks': remarks,
      'evaluation_date': evaluationDate,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory EvaluationModel.fromMap(Map<String, dynamic> map) {
    return EvaluationModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      domain: map['domain'] ?? '',
      score: map['score'] ?? 0,
      remarks: map['remarks'] ?? '',
      evaluationDate: map['evaluation_date'] ?? '',
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  EvaluationModel copyWith({
    int? id,
    String? childId,
    String? domain,
    int? score,
    String? remarks,
    String? evaluationDate,
    String? updatedAt,
    bool? isSynced,
  }) {
    return EvaluationModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      domain: domain ?? this.domain,
      score: score ?? this.score,
      remarks: remarks ?? this.remarks,
      evaluationDate: evaluationDate ?? this.evaluationDate,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
