import 'dart:io';
import 'dart:typed_data';
import '../../core/services/storage_service.dart';

class StorageDataSource {
  final StorageService _storageService;

  StorageDataSource({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  Future<String> uploadFile(String bucket, String path, File file) {
    return _storageService.uploadFile(bucket: bucket, path: path, file: file);
  }

  Future<String> uploadBytes(String bucket, String path, Uint8List bytes, {String? contentType}) {
    return _storageService.uploadBytes(bucket: bucket, path: path, bytes: bytes, contentType: contentType);
  }

  String getPublicUrl(String bucket, String path) {
    return _storageService.getPublicUrl(bucket: bucket, path: path);
  }
}
