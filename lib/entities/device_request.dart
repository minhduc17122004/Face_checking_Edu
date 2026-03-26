enum DeviceRequestStatus {
  pending,
  approved,
  rejected;

  static DeviceRequestStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'APPROVED':
        return DeviceRequestStatus.approved;
      case 'REJECTED':
        return DeviceRequestStatus.rejected;
      default:
        return DeviceRequestStatus.pending;
    }
  }

  String get value {
    switch (this) {
      case DeviceRequestStatus.pending:
        return 'PENDING';
      case DeviceRequestStatus.approved:
        return 'APPROVED';
      case DeviceRequestStatus.rejected:
        return 'REJECTED';
    }
  }

  String get label {
    switch (this) {
      case DeviceRequestStatus.pending:
        return 'Đang chờ';
      case DeviceRequestStatus.approved:
        return 'Đã duyệt';
      case DeviceRequestStatus.rejected:
        return 'Từ chối';
    }
  }
}

class DeviceRequest {
  final String id;
  final String deviceCode;
  final String? deviceName;
  final String? roomId;
  final String? roomName;
  final String? requestedBy;
  final String? requesterName;
  final DeviceRequestStatus status;
  final String? reviewedBy;
  final String? reviewerName;
  final DateTime? reviewedAt;
  final String? adminNote;
  final DateTime createdAt;

  const DeviceRequest({
    required this.id,
    required this.deviceCode,
    this.deviceName,
    this.roomId,
    this.roomName,
    this.requestedBy,
    this.requesterName,
    this.status = DeviceRequestStatus.pending,
    this.reviewedBy,
    this.reviewerName,
    this.reviewedAt,
    this.adminNote,
    required this.createdAt,
  });

  factory DeviceRequest.fromJson(Map<String, dynamic> json) {
    return DeviceRequest(
      id: json['id'] as String,
      deviceCode: json['device_code'] as String,
      deviceName: json['device_name'] as String?,
      roomId: json['room_id'] as String?,
      roomName: json['room_name'] as String?,
      requestedBy: json['requested_by'] as String?,
      requesterName: json['requester_name'] as String?,
      status: DeviceRequestStatus.fromString(json['status'] as String?),
      reviewedBy: json['reviewed_by'] as String?,
      reviewerName: json['reviewer_name'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      adminNote: json['admin_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_code': deviceCode,
      'device_name': deviceName,
      'room_id': roomId,
    };
  }

  DeviceRequest copyWith({
    String? id,
    String? deviceCode,
    String? deviceName,
    String? roomId,
    String? roomName,
    String? requestedBy,
    String? requesterName,
    DeviceRequestStatus? status,
    String? reviewedBy,
    String? reviewerName,
    DateTime? reviewedAt,
    String? adminNote,
    DateTime? createdAt,
  }) {
    return DeviceRequest(
      id: id ?? this.id,
      deviceCode: deviceCode ?? this.deviceCode,
      deviceName: deviceName ?? this.deviceName,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      requestedBy: requestedBy ?? this.requestedBy,
      requesterName: requesterName ?? this.requesterName,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      adminNote: adminNote ?? this.adminNote,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPending => status == DeviceRequestStatus.pending;
  bool get isApproved => status == DeviceRequestStatus.approved;
  bool get isRejected => status == DeviceRequestStatus.rejected;

  @override
  String toString() =>
      'DeviceRequest(id: $id, code: $deviceCode, status: ${status.value})';
}
