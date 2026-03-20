/// Request model for registering a new user (student or teacher)
class RegisterUserRequest {
  final String email;
  final String password;
  final String fullName;
  final String role; // 'student' or 'teacher'
  final String? pin;
  final String? jobTitle; // className for students, subject for teachers

  RegisterUserRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    this.pin,
    this.jobTitle,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'full_name': fullName,
      'role': role,
      if (pin != null && pin!.isNotEmpty) 'pin': pin,
      if (jobTitle != null && jobTitle!.isNotEmpty) 'job_title': jobTitle,
    };
  }

  @override
  String toString() {
    return 'RegisterUserRequest(email: $email, role: $role, fullName: $fullName)';
  }
}

/// Response model for user registration (mirrors TokenResponse from backend)
class RegisterUserResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final UserInfo user;

  RegisterUserResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory RegisterUserResponse.fromJson(Map<String, dynamic> json) {
    return RegisterUserResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as int,
      user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class UserInfo {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final String? createdAt;

  UserInfo({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.createdAt,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
