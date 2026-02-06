class UploadResponse {
  final String uploadId;
  final List<UploadedFile> files;
  final String expiresAt;
  final List<String>? failedFiles;

  UploadResponse({
    required this.uploadId,
    required this.files,
    required this.expiresAt,
    this.failedFiles,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      uploadId: json['upload_id'] as String,
      files: (json['files'] as List)
          .map((file) => UploadedFile.fromJson(file as Map<String, dynamic>))
          .toList(),
      expiresAt: json['expires_at'] as String,
      failedFiles: json['failed_files'] != null
          ? List<String>.from(json['failed_files'] as List)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'upload_id': uploadId,
      'files': files.map((file) => file.toJson()).toList(),
      'expires_at': expiresAt,
      'failed_files': failedFiles,
    };
  }
}

class UploadedFile {
  final String tempId;
  final String filename;
  final int size;
  final String mimetype;

  UploadedFile({
    required this.tempId,
    required this.filename,
    required this.size,
    required this.mimetype,
  });

  factory UploadedFile.fromJson(Map<String, dynamic> json) {
    return UploadedFile(
      tempId: json['temp_id'] as String,
      filename: json['filename'] as String,
      size: json['size'] as int,
      mimetype: json['mimetype'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temp_id': tempId,
      'filename': filename,
      'size': size,
      'mimetype': mimetype,
    };
  }
}