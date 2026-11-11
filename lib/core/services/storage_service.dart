import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class StorageService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<String> uploadFile({
    required String bucket,
    required String path,
    required File file,
  }) async {
    await _client.storage
        .from(bucket)
        .upload(
          path,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
    return createSignedUrl(bucket: bucket, path: path);
  }

  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String? contentType,
  }) async {
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: contentType,
            ),
          );
      return await createSignedUrl(bucket: bucket, path: path);
    } on StorageException catch (error) {
      if (error.message.toLowerCase().contains('bucket not found')) {
        throw StateError(
          'Secure evidence storage is not configured. An administrator must create the eccd-files bucket first.',
        );
      }
      rethrow;
    }
  }

  Future<String> createSignedUrl({
    required String bucket,
    required String path,
    int expiresIn = 3600,
  }) {
    return _client.storage.from(bucket).createSignedUrl(path, expiresIn);
  }
}
