import '../entities/practice_activity.dart';
import '../entities/practice_completion.dart';

abstract interface class PracticeActivityRepository {
  Future<List<PracticeActivity>> getActivities({PracticeDomain? domain});

  Future<List<PracticeCompletion>> getCompletions({
    required String parentUid,
    String? childId,
  });

  Future<void> markCompleted({
    required PracticeActivity activity,
    required String parentUid,
    String? childId,
  });
}
