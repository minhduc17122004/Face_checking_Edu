class UserInfo {
  String? id;
  String? email;
  String? role;
  String? fullName;
  String? avatarUrl;
  String? studentCode;
  String? className;
  String? departmentName;

  UserInfo({
    this.id,
    this.email,
    this.role,
    this.fullName,
    this.avatarUrl,
    this.studentCode,
    this.className,
    this.departmentName,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'],
      email: json['email'],
      role: json['role'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      studentCode: json['student_code'],
      className: json['class_name'],
      departmentName: json['department_name'],
    );
  }
}

class LoginResponse {
  String? token;
  String? refreshToken;
  UserInfo? user;

  LoginResponse({this.token, this.refreshToken, this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['access_token'],
      refreshToken: json['refresh_token'],
      user: json['user'] != null ? UserInfo.fromJson(json['user']) : null,
    );
  }
}
