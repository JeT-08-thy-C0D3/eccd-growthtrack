import '../../domain/entities/practice_activity.dart';

class PracticeActivityModel extends PracticeActivity {
  const PracticeActivityModel({
    required super.id,
    required super.title,
    required super.domain,
    required super.description,
    required super.instructions,
    required super.difficulty,
    required super.estimatedDurationMinutes,
  });

  factory PracticeActivityModel.fromMap(Map<String, dynamic> map) {
    return PracticeActivityModel(
      id: map['id'] as String,
      title: map['title'] as String,
      domain: PracticeDomain.values.firstWhere(
        (value) => value.name == map['domain'],
      ),
      description: map['description'] as String,
      instructions: (map['instructions'] as String)
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList(),
      difficulty: PracticeDifficulty.values.firstWhere(
        (value) => value.name == map['difficulty'],
      ),
      estimatedDurationMinutes: map['estimated_duration_minutes'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'domain': domain.name,
      'description': description,
      'instructions': instructions.join('\n'),
      'difficulty': difficulty.name,
      'estimated_duration_minutes': estimatedDurationMinutes,
    };
  }
}
