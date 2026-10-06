import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/practice_activity.dart';
import '../../domain/entities/practice_completion.dart';
import '../models/practice_activity_model.dart';
import '../models/practice_completion_model.dart';

class PracticeActivityLocalDataSource {
  static const _databaseName = 'eccd_practice_activities.db';
  static Database? _database;
  static final List<PracticeCompletionModel> _webCompletions = [];

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final databasesPath = await getDatabasesPath();
    _database = await openDatabase(
      join(databasesPath, _databaseName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE practice_activities (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            domain TEXT NOT NULL,
            description TEXT NOT NULL,
            instructions TEXT NOT NULL,
            difficulty TEXT NOT NULL,
            estimated_duration_minutes INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE practice_activity_completions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activity_id TEXT NOT NULL,
            activity_title TEXT NOT NULL,
            domain_label TEXT NOT NULL,
            parent_uid TEXT NOT NULL,
            child_id TEXT,
            completed_at TEXT NOT NULL,
            UNIQUE(activity_id, parent_uid, child_id)
          )
        ''');
      },
    );
    return _database!;
  }

  Future<List<PracticeActivity>> getActivities({PracticeDomain? domain}) async {
    if (kIsWeb) {
      final activities = _seedActivities;
      return domain == null
          ? activities
          : activities.where((activity) => activity.domain == domain).toList();
    }

    final db = await _db;
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM practice_activities'),
        ) ??
        0;
    if (count == 0) {
      await db.transaction((transaction) async {
        for (final activity in _seedActivities) {
          await transaction.insert(
            'practice_activities',
            PracticeActivityModel(
              id: activity.id,
              title: activity.title,
              domain: activity.domain,
              description: activity.description,
              instructions: activity.instructions,
              difficulty: activity.difficulty,
              estimatedDurationMinutes: activity.estimatedDurationMinutes,
            ).toMap(),
          );
        }
      });
    }

    final rows = await db.query(
      'practice_activities',
      where: domain == null ? null : 'domain = ?',
      whereArgs: domain == null ? null : [domain.name],
      orderBy: 'domain ASC, title ASC',
    );
    return rows.map(PracticeActivityModel.fromMap).toList();
  }

  Future<List<PracticeCompletion>> getCompletions({
    required String parentUid,
    String? childId,
  }) async {
    if (kIsWeb) {
      return _webCompletions
          .where((completion) =>
              completion.parentUid == parentUid &&
              (childId == null || completion.childId == childId))
          .toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    }

    final db = await _db;
    final rows = await db.query(
      'practice_activity_completions',
      where: childId == null
          ? 'parent_uid = ?'
          : 'parent_uid = ? AND child_id = ?',
      whereArgs: childId == null ? [parentUid] : [parentUid, childId],
      orderBy: 'completed_at DESC',
    );
    return rows.map(PracticeCompletionModel.fromMap).toList();
  }

  Future<void> markCompleted({
    required PracticeActivity activity,
    required String parentUid,
    String? childId,
  }) async {
    final completion = PracticeCompletionModel(
      activityId: activity.id,
      activityTitle: activity.title,
      domainLabel: activity.domain.label,
      parentUid: parentUid,
      childId: childId,
      completedAt: DateTime.now(),
    );

    if (kIsWeb) {
      final alreadyCompleted = _webCompletions.any((item) =>
          item.activityId == activity.id &&
          item.parentUid == parentUid &&
          item.childId == childId);
      if (!alreadyCompleted) _webCompletions.add(completion);
      return;
    }

    final db = await _db;
    final existing = await db.query(
      'practice_activity_completions',
      where: childId == null
          ? 'activity_id = ? AND parent_uid = ? AND child_id IS NULL'
          : 'activity_id = ? AND parent_uid = ? AND child_id = ?',
      whereArgs: childId == null
          ? [activity.id, parentUid]
          : [activity.id, parentUid, childId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await db.insert(
      'practice_activity_completions',
      completion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static const List<PracticeActivity> _seedActivities = [
    PracticeActivity(
      id: 'gross-motor-balance-path',
      title: 'Balance Path',
      domain: PracticeDomain.grossMotor,
      description: 'Create a safe path for walking, stepping, and balancing.',
      instructions: [
        'Place cushions, paper shapes, or a line of tape on the floor.',
        'Invite the child to walk from one end to the other.',
        'Offer a hand for support when needed and celebrate trying.',
      ],
      difficulty: PracticeDifficulty.easy,
      estimatedDurationMinutes: 10,
    ),
    PracticeActivity(
      id: 'gross-motor-animal-moves',
      title: 'Animal Movement Game',
      domain: PracticeDomain.grossMotor,
      description: 'Move like different animals to practise whole-body control.',
      instructions: [
        'Name an animal such as a frog, bear, or bird.',
        'Take turns showing how that animal moves.',
        'Let the child choose the next animal.',
      ],
      difficulty: PracticeDifficulty.moderate,
      estimatedDurationMinutes: 15,
    ),
    PracticeActivity(
      id: 'fine-motor-tong-transfer',
      title: 'Tong Transfer',
      domain: PracticeDomain.fineMotor,
      description: 'Use tongs or a safe kitchen spoon to move objects between bowls.',
      instructions: [
        'Place large pom-poms, blocks, or rolled socks in one bowl.',
        'Show how to move one object to another bowl.',
        'Let the child try and switch hands if comfortable.',
      ],
      difficulty: PracticeDifficulty.easy,
      estimatedDurationMinutes: 10,
    ),
    PracticeActivity(
      id: 'fine-motor-shape-collage',
      title: 'Shape Collage',
      domain: PracticeDomain.fineMotor,
      description: 'Tear, place, and glue paper shapes to make a picture.',
      instructions: [
        'Offer scrap paper and a sheet of paper as the background.',
        'Invite the child to tear or fold pieces into different shapes.',
        'Arrange and glue the pieces together.',
      ],
      difficulty: PracticeDifficulty.moderate,
      estimatedDurationMinutes: 20,
    ),
    PracticeActivity(
      id: 'self-help-dressing-practice',
      title: 'Dressing Practice',
      domain: PracticeDomain.selfHelp,
      description: 'Practise one dressing step during a calm part of the day.',
      instructions: [
        'Choose one safe item such as socks, a shirt, or a jacket.',
        'Break the task into small steps and model the first one.',
        'Allow time for the child to try before helping.',
      ],
      difficulty: PracticeDifficulty.moderate,
      estimatedDurationMinutes: 10,
    ),
    PracticeActivity(
      id: 'self-help-clean-up-routine',
      title: 'Clean-Up Routine',
      domain: PracticeDomain.selfHelp,
      description: 'Build independence by putting familiar items back in place.',
      instructions: [
        'Choose three to five toys or materials.',
        'Show where each item belongs.',
        'Use a simple song or countdown while cleaning up together.',
      ],
      difficulty: PracticeDifficulty.easy,
      estimatedDurationMinutes: 10,
    ),
    PracticeActivity(
      id: 'receptive-language-listen-and-find',
      title: 'Listen and Find',
      domain: PracticeDomain.receptiveLanguage,
      description: 'Practise understanding simple directions using familiar objects.',
      instructions: [
        'Place two or three familiar objects nearby.',
        'Ask the child to find or bring one named object.',
        'Gradually add a second step such as “find the cup and put it here.”',
      ],
      difficulty: PracticeDifficulty.moderate,
      estimatedDurationMinutes: 10,
    ),
    PracticeActivity(
      id: 'receptive-language-sound-hunt',
      title: 'Sound Hunt',
      domain: PracticeDomain.receptiveLanguage,
      description: 'Listen carefully and connect sounds to where they come from.',
      instructions: [
        'Pause together and listen for sounds around you.',
        'Ask, “What did you hear?” and offer choices if needed.',
        'Move safely toward the sound and talk about it.',
      ],
      difficulty: PracticeDifficulty.easy,
      estimatedDurationMinutes: 10,
    ),
    PracticeActivity(
      id: 'expressive-language-story-bag',
      title: 'Story Bag',
      domain: PracticeDomain.expressiveLanguage,
      description: 'Use a few household items to build a short story together.',
      instructions: [
        'Put three familiar objects in a bag.',
        'Take turns pulling out an object and adding to the story.',
        'Repeat and expand the child’s words without correcting them.',
      ],
      difficulty: PracticeDifficulty.moderate,
      estimatedDurationMinutes: 15,
    ),
    PracticeActivity(
      id: 'expressive-language-picture-talk',
      title: 'Picture Talk',
      domain: PracticeDomain.expressiveLanguage,
      description: 'Talk about a picture, family moment, or object of interest.',
      instructions: [
        'Choose one picture or object the child enjoys.',
        'Ask open questions such as “What is happening?”',
        'Give the child time to answer and follow their ideas.',
      ],
      difficulty: PracticeDifficulty.easy,
      estimatedDurationMinutes: 10,
    ),
    PracticeActivity(
      id: 'cognitive-sort-and-match',
      title: 'Sort and Match',
      domain: PracticeDomain.cognitive,
      description: 'Notice similarities and differences by sorting everyday items.',
      instructions: [
        'Gather safe items that differ by colour, shape, or size.',
        'Ask the child to make groups in any way they choose.',
        'Talk about why items belong together.',
      ],
      difficulty: PracticeDifficulty.moderate,
      estimatedDurationMinutes: 15,
    ),
    PracticeActivity(
      id: 'cognitive-sequence-the-day',
      title: 'Sequence the Day',
      domain: PracticeDomain.cognitive,
      description: 'Recall and order familiar events from the child’s day.',
      instructions: [
        'Name two or three things that happened today.',
        'Ask what happened first, next, and last.',
        'Use drawings or simple objects to help show the order.',
      ],
      difficulty: PracticeDifficulty.moderate,
      estimatedDurationMinutes: 10,
    ),
    PracticeActivity(
      id: 'social-emotional-feelings-check-in',
      title: 'Feelings Check-In',
      domain: PracticeDomain.socialEmotional,
      description: 'Help the child notice and name feelings in a supportive way.',
      instructions: [
        'Offer two or three feeling words or simple faces.',
        'Ask how the child feels and accept their answer.',
        'Share one calm strategy such as breathing or asking for a hug.',
      ],
      difficulty: PracticeDifficulty.easy,
      estimatedDurationMinutes: 10,
    ),
    PracticeActivity(
      id: 'social-emotional-turn-taking',
      title: 'Turn-Taking Together',
      domain: PracticeDomain.socialEmotional,
      description: 'Practise waiting, sharing, and taking turns during a short game.',
      instructions: [
        'Choose a simple game with a clear turn, such as rolling a ball.',
        'Use “my turn” and “your turn” language.',
        'Praise waiting and friendly communication.',
      ],
      difficulty: PracticeDifficulty.moderate,
      estimatedDurationMinutes: 15,
    ),
    PracticeActivity(
      id: 'moral-cultural-gratitude',
      title: 'Gratitude Moment',
      domain: PracticeDomain.moralSpiritualCultural,
      description: 'Share a short family gratitude or appreciation practice.',
      instructions: [
        'Choose a quiet moment together.',
        'Each person names one person, place, or thing they appreciate.',
        'Connect the conversation to your family’s values or traditions.',
      ],
      difficulty: PracticeDifficulty.easy,
      estimatedDurationMinutes: 10,
    ),
    PracticeActivity(
      id: 'moral-cultural-family-tradition',
      title: 'Family Tradition Share',
      domain: PracticeDomain.moralSpiritualCultural,
      description: 'Share a song, story, greeting, or practice that matters to your family.',
      instructions: [
        'Choose one tradition that is meaningful and age-appropriate.',
        'Tell the child where it came from and why it matters.',
        'Invite the child to join in or ask questions.',
      ],
      difficulty: PracticeDifficulty.moderate,
      estimatedDurationMinutes: 15,
    ),
  ];
}
