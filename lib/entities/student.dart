import 'package:face_time_keeping/entities/person.dart';

class Student {
  final int id;
  final String? pin;
  final String name;
  final dynamic jobTitle;
  final bool hasAvatar;
  final dynamic error;
  final String? attachmentId;
  final String? avatar;
  final bool isFromServer;
  final bool hasFace;
  /// UUID from backend — used to identify student when syncing to server
  final String? serverUserId;

  Student({
    required this.id,
    required this.pin,
    required this.name,
    this.jobTitle,
    this.hasAvatar = false,
    this.error,
    this.attachmentId,
    this.avatar,
    this.isFromServer = false,
    this.hasFace = false,
    this.serverUserId,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
        id: json['id'] as int,
        pin: json['pin'] is String ? json['pin'] as String : null,
        name: json['name'] as String,
        jobTitle: json['job_title'],
        hasAvatar: json['has_avatar'] as bool? ?? false,
        error: json['error'],
        attachmentId: json['attachment_id'] is String
            ? json['attachment_id'] as String
            : null,
        avatar:
            json['avatar_url'] is String ? json['avatar_url'] as String : null);
  }

  /// Construct from a User API response (UUID string id).
  factory Student.fromUserJson(Map<String, dynamic> json) {
    final idStr = json['id'] as String;
    final idInt = idStr.hashCode;
    final pin = json['student_code'] as String?;
    return Student(
      id: idInt.abs(),
      pin: pin,
      name: json['full_name'] as String,
      jobTitle: null,
      hasAvatar: (json['avatar_url'] as String?)?.isNotEmpty ?? false,
      error: null,
      attachmentId: null,
      avatar: json['avatar_url'] as String?,
      isFromServer: true,
      serverUserId: idStr, // Store the original UUID
    );
  }

  factory Student.fromErrorJson(Map<String, dynamic> json) {
    return Student(
      id: -1,
      pin: json['pin'] is String ? json['pin'] as String : null,
      name: json['name'] as String,
      jobTitle: json['job_title'],
      hasAvatar: json['has_avatar'] as bool? ?? false,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pin': pin,
      'name': name,
      'job_title': jobTitle,
      'has_avatar': hasAvatar,
      'error': error,
      'attachment_id': attachmentId,
      'avatar_url': avatar,
      'is_from_server': isFromServer,
      'server_user_id': serverUserId,
    };
  }

  @override
  String toString() {
    return 'Student(id: $id, pin: $pin, name: $name, jobTitle: $jobTitle)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Student &&
        other.id == id &&
        other.pin == pin &&
        other.name == name &&
        other.jobTitle == jobTitle;
  }

  @override
  int get hashCode {
    return id.hashCode ^ pin.hashCode ^ name.hashCode ^ jobTitle.hashCode;
  }

  Student copyWith({
    int? id,
    String? pin,
    dynamic barcode,
    String? name,
    dynamic jobTitle,
    bool? isFromServer,
    bool? hasFace,
    String? serverUserId,
  }) {
    return Student(
      id: id ?? this.id,
      pin: pin ?? this.pin,
      name: name ?? this.name,
      jobTitle: jobTitle ?? this.jobTitle,
      isFromServer: isFromServer ?? this.isFromServer,
      hasFace: hasFace ?? this.hasFace,
      serverUserId: serverUserId ?? this.serverUserId,
    );
  }

  Person toPerson() {
    return Person(
      studentId: id,
      pin: pin,
      name: name,
      jobTitle: jobTitle,
      updatedTime: DateTime.now(),
    );
  }
}
