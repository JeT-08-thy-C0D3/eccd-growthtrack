class AssessmentModel {
  final int? id;
  final int childId;
  final String date;
  final String domain; // e.g., Gross Motor, Fine Motor, etc.
  final int score;
  final String remarks;

  AssessmentModel({
    this.id,
    required this.childId,
    required this.date,
    required this.domain,
    required this.score,
    required this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'date': date,
      'domain': domain,
      'score': score,
      'remarks': remarks,
    };
  }

  factory AssessmentModel.fromMap(Map<String, dynamic> map) {
    return AssessmentModel(
      id: map['id'],
      childId: map['child_id'],
      date: map['date'],
      domain: map['domain'],
      score: map['score'],
      remarks: map['remarks'],
    );
  }
}
