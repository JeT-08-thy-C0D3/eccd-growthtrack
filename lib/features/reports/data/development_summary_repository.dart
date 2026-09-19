import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../domain/development_summary_model.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/utils/audit_logger.dart';

abstract class DevelopmentSummaryRepository {
  Future<int> addSummary(DevelopmentSummaryModel summary);
  Future<List<Map<String, dynamic>>> getHistory(String childId);
  Future<int> updateStatus(int id, String status, String approvedBy, String approvedDate);
}

class DevelopmentSummaryRepositoryImpl implements DevelopmentSummaryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  Future<int> addSummary(DevelopmentSummaryModel summary) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final newSummary = summary.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    final id = await _local.saveRecord('development_summaries', newSummary.toMap());
    
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('development_summaries', id.toString(), newSummary.toMap());
        await _local.markAsSynced('development_summaries', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    await AuditLogger.log(
      action: 'Create AI Summary',
      module: 'Development Summary',
      description: 'Drafted development summary for child ID ${summary.childId}.',
    );

    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory(String childId) async {
    return await _dbHelper.getDevelopmentSummaryHistory(childId);
  }

  @override
  Future<int> updateStatus(int id, String status, String approvedBy, String approvedDate) async {
    final result = await _dbHelper.updateDevelopmentSummaryStatus(id, status, approvedBy, approvedDate);
    
    await AuditLogger.log(
      action: 'Review Summary',
      module: 'Development Summary',
      description: 'Teacher $approvedBy reviewed summary ID $id as $status.',
    );

    return result;
  }
}
