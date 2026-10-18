import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../datasources/storage_data_source.dart';
import '../datasources/local_data_source.dart';
import '../datasources/remote_data_source.dart';
import '../../core/network/connectivity_service.dart';
import '../../shared/models/file_upload_model.dart';
import '../../core/config/supabase_config.dart';

class FileUploadRepository {
  final StorageDataSource _storageDataSource;
  final LocalDataSource _localDataSource;
  final RemoteDataSource _remoteDataSource;
  final ConnectivityService _connectivityService;

  FileUploadRepository({
    StorageDataSource? storageDataSource,
    LocalDataSource? localDataSource,
    RemoteDataSource? remoteDataSource,
    ConnectivityService? connectivityService,
  })  : _storageDataSource = storageDataSource ?? StorageDataSource(),
        _localDataSource = localDataSource ?? LocalDataSource(),
        _remoteDataSource = remoteDataSource ?? RemoteDataSource(),
        _connectivityService = connectivityService ?? ConnectivityService();

  Future<String?> uploadFile({
    required String bucket,
    required String entityId,
    required String category,
    required String filePath,
    String? docCollection,
    String? urlFieldName,
  }) async {
    final fileId = '${category}_${entityId}_${DateTime.now().millisecondsSinceEpoch}';
    final storagePath = '$category/$entityId/${fileId}_${filePath.split('/').last}';
    final isOnline = await _connectivityService.isOnline;

    if (isOnline || kIsWeb) {
      try {
        final file = File(filePath);
        final signedUrl = await _storageDataSource.uploadFile(bucket, storagePath, file);

        // Save URL in Firestore if collection and field name provided
        if (docCollection != null && urlFieldName != null) {
          await _remoteDataSource.updateDocumentFileUrl(docCollection, entityId, urlFieldName, signedUrl);
        }

        // Cache metadata in SQLite
        final uploadModel = FileUploadModel(
          fileId: fileId,
          entityId: entityId,
          category: category,
          localPath: filePath,
          remoteUrl: signedUrl,
          createdAt: DateTime.now().toIso8601String(),
          isSynced: true,
        );
        await _localDataSource.saveFileUpload(uploadModel);

        return signedUrl;
      } catch (e) {
        print("FileUploadRepository uploadFile error: $e");
        // Fall back to offline queue on error if on mobile
        if (!kIsWeb) {
          await _queueOfflineFile(fileId, entityId, category, filePath);
        }
        return null;
      }
    } else {
      // Offline mode: queue in SQLite
      await _queueOfflineFile(fileId, entityId, category, filePath);
      return null;
    }
  }

  Future<String?> uploadBytes({
    required String bucket,
    required String entityId,
    required String category,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
    String? docCollection,
    String? urlFieldName,
  }) async {
    final fileId = '${category}_${entityId}_${DateTime.now().millisecondsSinceEpoch}';
    final storagePath = '$category/$entityId/${fileId}_$fileName';

    try {
      final signedUrl = await _storageDataSource.uploadBytes(
        bucket,
        storagePath,
        bytes,
        contentType: contentType,
      );

      if (docCollection != null && urlFieldName != null) {
        await _remoteDataSource.updateDocumentFileUrl(docCollection, entityId, urlFieldName, signedUrl);
      }

      final uploadModel = FileUploadModel(
        fileId: fileId,
        entityId: entityId,
        category: category,
        localPath: fileName,
        remoteUrl: signedUrl,
        createdAt: DateTime.now().toIso8601String(),
        isSynced: true,
      );
      await _localDataSource.saveFileUpload(uploadModel);

      return signedUrl;
    } catch (e) {
      print("FileUploadRepository uploadBytes error: $e");
      return null;
    }
  }

  Future<void> _queueOfflineFile(String fileId, String entityId, String category, String filePath) async {
    final uploadModel = FileUploadModel(
      fileId: fileId,
      entityId: entityId,
      category: category,
      localPath: filePath,
      remoteUrl: null,
      createdAt: DateTime.now().toIso8601String(),
      isSynced: false,
    );
    await _localDataSource.saveFileUpload(uploadModel);
  }

  Future<void> syncPendingFileUploads() async {
    if (kIsWeb) return;
    final isOnline = await _connectivityService.isOnline;
    if (!isOnline) return;

    final pending = await _localDataSource.getUnsyncedFileUploads();
    for (var record in pending) {
      try {
        final file = File(record.localPath);
        if (!file.existsSync()) continue;

        final storagePath = '${record.category}/${record.entityId}/${record.fileId}_${record.localPath.split('/').last}';
        final signedUrl = await _storageDataSource.uploadFile(
          SupabaseConfig.filesBucket,
          storagePath,
          file,
        );

        await _localDataSource.markFileUploadSynced(record.fileId, signedUrl);
        print("Successfully synced file upload: ${record.fileId}");
      } catch (e) {
        print("Error syncing pending file upload [${record.fileId}]: $e");
      }
    }
  }
}
