class FileUploadModel {
  final int? id;
  final String fileId;
  final String entityId;
  final String category;
  final String localPath;
  final String? remoteUrl;
  final String createdAt;
  final bool isSynced;

  FileUploadModel({
    this.id,
    required this.fileId,
    required this.entityId,
    required this.category,
    required this.localPath,
    this.remoteUrl,
    required this.createdAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'file_id': fileId,
      'entity_id': entityId,
      'category': category,
      'local_path': localPath,
      'remote_url': remoteUrl,
      'created_at': createdAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory FileUploadModel.fromMap(Map<String, dynamic> map) {
    return FileUploadModel(
      id: map['id'] as int?,
      fileId: map['file_id'] as String,
      entityId: map['entity_id'] as String,
      category: map['category'] as String,
      localPath: map['local_path'] as String,
      remoteUrl: map['remote_url'] as String?,
      createdAt: map['created_at'] as String,
      isSynced: (map['is_synced'] as int?) == 1,
    );
  }

  FileUploadModel copyWith({
    int? id,
    String? fileId,
    String? entityId,
    String? category,
    String? localPath,
    String? remoteUrl,
    String? createdAt,
    bool? isSynced,
  }) {
    return FileUploadModel(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      entityId: entityId ?? this.entityId,
      category: category ?? this.category,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
