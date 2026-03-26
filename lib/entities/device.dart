class Device {
  final String id;
  final String deviceCode;
  final String? deviceName;
  final String? roomId;
  final String? roomName;
  final String? isGlobal;
  final String? status;
  final String? deviceType;
  final String? ipAddress;
  final DateTime? lastActiveAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Device({
    required this.id,
    required this.deviceCode,
    this.deviceName,
    this.roomId,
    this.roomName,
    this.isGlobal,
    this.status,
    this.deviceType,
    this.ipAddress,
    this.lastActiveAt,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isGlobalFlag => isGlobal == 'true' || isGlobal == true;
  bool get isActive => status == 'ACTIVE' || status == true;
  bool get isOnline {
    if (lastActiveAt == null) return false;
    return DateTime.now().difference(lastActiveAt!).inMinutes < 5;
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      deviceCode: json['device_code'] as String,
      deviceName: json['device_name'] as String?,
      roomId: json['room_id'] as String?,
      roomName: json['room_name'] as String?,
      isGlobal: json['is_global']?.toString(),
      status: json['status'] as String?,
      deviceType: json['device_type'] as String?,
      ipAddress: json['ip_address'] as String?,
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.parse(json['last_active_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_code': deviceCode,
      'device_name': deviceName,
      'room_id': roomId,
      'is_global': isGlobal,
      'status': status,
      'device_type': deviceType,
      'ip_address': ipAddress,
    };
  }

  Device copyWith({
    String? id,
    String? deviceCode,
    String? deviceName,
    String? roomId,
    String? roomName,
    String? isGlobal,
    String? status,
    String? deviceType,
    String? ipAddress,
    DateTime? lastActiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Device(
      id: id ?? this.id,
      deviceCode: deviceCode ?? this.deviceCode,
      deviceName: deviceName ?? this.deviceName,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      isGlobal: isGlobal ?? this.isGlobal,
      status: status ?? this.status,
      deviceType: deviceType ?? this.deviceType,
      ipAddress: ipAddress ?? this.ipAddress,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Device(id: $id, code: $deviceCode, status: $status)';
}
