import '../../domain/entities/practice_activity.dart';
import '../../domain/entities/practice_completion.dart';
import '../../domain/repositories/practice_activity_repository.dart';
import '../datasources/practice_activity_local_data_source.dart';

class PracticeActivityRepositoryImpl implements PracticeActivityRepository {
  PracticeActivityRepositoryImpl({PracticeActivityLocalDataSource? localDataSource})
      : _localDataSource = localDataSource ?? PracticeActivityLocalDataSource();

  final PracticeActivityLocalDataSource _localDataSource;

  @override
  Future<List<PracticeActivity>> getActivities({PracticeDomain? domain}) {
    return _localDataSource.getActivities(domain: domain);
  }

  @override
  Future<List<PracticeCompletion>> getCompletions({
    required String parentUid,
    String? childId,
  }) {
    return _localDataSource.getCompletions(
      parentUid: parentUid,
      childId: childId,
    );
  }

  @override
  Future<void> markCompleted({
    required PracticeActivity activity,
    required String parentUid,
    String? childId,
  }) {
    return _localDataSource.markCompleted(
      activity: activity,
      parentUid: parentUid,
      childId: childId,
    );
  }
}
