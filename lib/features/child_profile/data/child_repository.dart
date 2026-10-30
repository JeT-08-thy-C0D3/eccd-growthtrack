import '../../../shared/models/child_model.dart';
import '../../../core/database/database_helper.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../data/repositories/file_upload_repository.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/utils/audit_logger.dart';

abstract class ChildRepository {
  Future<int> addChild(ChildModel child);
  Future<List<ChildModel>> getChildren();
  Future<int> updateChild(ChildModel child);
  Future<int> deleteChild(int id);
  Future<String?> uploadProfilePhoto(String childId, String filePath);
}

class ChildRepositoryImpl implements ChildRepository {
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();
  final FileUploadRepository _fileUploadRepo = FileUploadRepository();

  @override
  Future<int> addChild(ChildModel child) async {
    if (await _hasDuplicateChild(child)) {
      throw StateError(
        'A child with the same name, birth date, and parent is already registered.',
      );
    }
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
      description:
          'Registered child: ${child.firstName} ${child.lastName} (ID: ${child.childId}).',
    );

    return id;
  }

  @override
  Future<List<ChildModel>> getChildren() async {
    // DatabaseHelper implements the shared local-first policy: SQLite is read
    // first on mobile and Firestore is used only to hydrate an empty cache.
    // Web has no SQLite support, so it reads Firestore directly.
    return await DatabaseHelper.instance.getAllChildren();
  }

  Future<bool> _hasDuplicateChild(ChildModel candidate) async {
    final firstName = candidate.firstName.trim().toLowerCase();
    final lastName = candidate.lastName.trim().toLowerCase();
    final parentUid = candidate.parentUid?.trim() ?? '';

    return (await getChildren()).any(
      (existing) =>
          existing.childId != candidate.childId &&
          existing.firstName.trim().toLowerCase() == firstName &&
          existing.lastName.trim().toLowerCase() == lastName &&
          existing.birthDate == candidate.birthDate &&
          (existing.parentUid?.trim() ?? '') == parentUid,
    );
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

  @override
  Future<String?> uploadProfilePhoto(String childId, String filePath) async {
    return await _fileUploadRepo.uploadFile(
      bucket: SupabaseConfig.childProfilePhotos,
      entityId: childId,
      category: SupabaseConfig.childProfileCategory,
      filePath: filePath,
      docCollection: 'children',
      urlFieldName: 'photo_url',
    );
  }
}
