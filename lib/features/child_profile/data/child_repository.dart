import '../../../shared/models/child_model.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../core/utils/audit_logger.dart';

abstract class ChildRepository {
  Future<int> addChild(ChildModel child);
  Future<List<ChildModel>> getChildren();
  Future<int> updateChild(ChildModel child);
  Future<int> deleteChild(int id);
}

class ChildRepositoryImpl implements ChildRepository {
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  Future<int> addChild(ChildModel child) async {
    // 1. ALWAYS save locally first
    final id = await _local.saveRecord('children', child.toMap());
    
    // 2. OPTIONAL: Attempt immediate cloud sync if online
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('children', child.childId, child.toMap());
        await _local.markAsSynced('children', child.childId);
      } catch (e) {
        // Silently fail; SyncService will retry later
      }
    }
    
    // Log addition
    await AuditLogger.log(
      action: 'Register Child',
      module: 'Child Registration',
      description: 'Registered child: ${child.firstName} ${child.lastName} (ID: ${child.childId}).',
    );
    
    return id;
  }

  @override
  Future<List<ChildModel>> getChildren() async {
    // Architecture choice: Always read from Local Cache for speed
    // Background sync handles keeping the cache fresh
    final List<Map<String, dynamic>> data = await _local.getUnsyncedRecords('children'); // Or read all from DB
    // Note: Use DatabaseHelper to read all, this is just showing the source.
    return data.map((e) => ChildModel.fromMap(e)).toList();
  }
  
  @override
  Future<int> updateChild(ChildModel child) async {
    final id = await addChild(child);
    
    // Log update
    await AuditLogger.log(
      action: 'Update Child',
      module: 'Child Registration',
      description: 'Updated profile for ${child.firstName} ${child.lastName}.',
    );
    
    return id;
  }

  @override
  Future<int> deleteChild(int id) async {
     // Local delete + cloud delete trigger
     return 0; // Simplified for example
  }
}
