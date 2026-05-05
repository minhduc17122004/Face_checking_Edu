class FaceData {
  final int studentId;
  final DateTime updatedTime;
  final List<List<double>> listFaceEmbedding;
  String? personName;

  /// Mã SV (MSSV) — stable identifier across DB resets.
  /// Mapped từ `pin` của Person / `student_code` của backend.
  String? studentCode;

  /// SHA-256 hex digest of embeddings — computed by server.
  /// Used for content comparison to avoid redundant imports.
  final String? embeddingHash;

  /// Server-side timestamp (UTC) of the latest embedding update.
  /// Separated from `updatedTime` (local) for deterministic sync.
  final DateTime serverUpdatedAt;

  FaceData({
    required this.studentId,
    required this.updatedTime,
    required this.listFaceEmbedding,
    this.personName,
    this.studentCode,
    this.embeddingHash,
    DateTime? serverUpdatedAt,
  }) : serverUpdatedAt = serverUpdatedAt ?? updatedTime;

  factory FaceData.fromJson(Map<String, dynamic> json) {
    // Backend trả về 'studentId'; legacy local data dùng 'empId'.
    final id = (json['studentId'] ?? json['empId']) as int;

    // Parse server timestamp — prefer 'updated_at' (ISO-8601 UTC from server),
    // fallback to 'updatedTime' (legacy local format)
    final rawUpdatedAt = json['updated_at'] ?? json['updatedTime'];
    final updatedTime = rawUpdatedAt != null
        ? DateTime.parse(rawUpdatedAt.toString()).toUtc()
        : DateTime.now().toUtc();

    return FaceData(
        studentId: id,
        updatedTime: updatedTime,
        serverUpdatedAt: updatedTime,
        listFaceEmbedding: (json['listFaceEmbedding'] as List)
            .map((item) => (item as List).cast<double>())
            .toList(),
        personName: json['personName'],
        // 'studentCode' từ backend v2 hoặc 'pin' từ dữ liệu cũ
        studentCode: json['studentCode'] as String? ?? json['pin'] as String?,
        embeddingHash: json['embedding_hash'] as String?);
  }

  Map<String, dynamic> toJson() {
    // Backend import_from_file() ưu tiên 'studentCode' (MSSV) → fallback 'studentId'
    return {
      'studentId': studentId,
      'studentCode':
          studentCode, // stable identifier — backend sẽ lookup theo đây trước
      'updatedTime': updatedTime.toIso8601String().split('.').first,
      'listFaceEmbedding': listFaceEmbedding,
      'personName': personName,
    };
  }
}
