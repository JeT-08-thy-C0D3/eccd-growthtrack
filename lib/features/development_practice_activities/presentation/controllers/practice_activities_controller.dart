import 'package:flutter/foundation.dart';

import '../../data/repositories/practice_activity_repository_impl.dart';
import '../../domain/entities/practice_activity.dart';
import '../../domain/entities/practice_completion.dart';
import '../../domain/repositories/practice_activity_repository.dart';
import '../../domain/usecases/browse_practice_activities.dart';
import '../../domain/usecases/complete_practice_activity.dart';
import '../../domain/usecases/get_completed_practice_activities.dart';

class PracticeActivitiesController extends ChangeNotifier {
  PracticeActivitiesController({PracticeActivityRepository? repository})
      : _repository = repository ?? PracticeActivityRepositoryImpl() {
    _browse = BrowsePracticeActivities(_repository);
    _complete = CompletePracticeActivity(_repository);
    _getCompleted = GetCompletedPracticeActivities(_repository);
  }

  final PracticeActivityRepository _repository;
  late final BrowsePracticeActivities _browse;
  late final CompletePracticeActivity _complete;
  late final GetCompletedPracticeActivities _getCompleted;

  List<PracticeActivity> activities = const [];
  List<PracticeCompletion> completions = const [];
  PracticeDomain? selectedDomain;
  bool isLoading = false;
  String? errorMessage;

  Set<String> get completedActivityIds =>
      completions.map((completion) => completion.activityId).toSet();

  Future<void> load({required String parentUid, String? childId}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      activities = await _browse(domain: selectedDomain);
      completions = await _getCompleted(
        parentUid: parentUid,
        childId: childId,
      );
    } catch (error) {
      errorMessage = 'Unable to load practice activities.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectDomain({
    required PracticeDomain? domain,
    required String parentUid,
    String? childId,
  }) async {
    selectedDomain = domain;
    await load(parentUid: parentUid, childId: childId);
  }

  Future<void> complete({
    required PracticeActivity activity,
    required String parentUid,
    String? childId,
  }) async {
    await _complete(
      activity: activity,
      parentUid: parentUid,
      childId: childId,
    );
    completions = await _getCompleted(
      parentUid: parentUid,
      childId: childId,
    );
    notifyListeners();
  }
}
