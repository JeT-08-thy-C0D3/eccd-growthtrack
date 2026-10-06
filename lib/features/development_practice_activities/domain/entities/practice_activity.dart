enum PracticeDomain {
  grossMotor('Gross Motor'),
  fineMotor('Fine Motor'),
  selfHelp('Self Help'),
  receptiveLanguage('Receptive Language'),
  expressiveLanguage('Expressive Language'),
  cognitive('Cognitive'),
  socialEmotional('Social Emotional'),
  moralSpiritualCultural('Moral, Spiritual, and Cultural Development');

  const PracticeDomain(this.label);

  final String label;
}

enum PracticeDifficulty {
  easy('Easy'),
  moderate('Moderate'),
  challenging('Challenging');

  const PracticeDifficulty(this.label);

  final String label;
}

class PracticeActivity {
  const PracticeActivity({
    required this.id,
    required this.title,
    required this.domain,
    required this.description,
    required this.instructions,
    required this.difficulty,
    required this.estimatedDurationMinutes,
  });

  final String id;
  final String title;
  final PracticeDomain domain;
  final String description;
  final List<String> instructions;
  final PracticeDifficulty difficulty;
  final int estimatedDurationMinutes;
}
