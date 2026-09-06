class EvaluationModel {
  final int? id;
  final String childId;
  final String domain;
  final int score;
  final String remarks;
  final String evaluationDate;

  EvaluationModel({
    this.id,
    required this.childId,
    required this.domain,
    required this.score,
    required this.remarks,
    required this.evaluationDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'domain': domain,
      'score': score,
      'remarks': remarks,
      'evaluation_date': evaluationDate,
    };
  }

  factory EvaluationModel.fromMap(Map<String, dynamic> map) {
    return EvaluationModel(
      id: map['id'],
      childId: map['child_id'],
      domain: map['domain'],
      score: map['score'],
      remarks: map['remarks'],
      evaluationDate: map['evaluation_date'],
    );
  }
}
