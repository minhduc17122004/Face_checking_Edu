class UserInfo {
  String? id;
  String? email;
  String? role;
  String? fullName;

  UserInfo({this.id, this.email, this.role, this.fullName});

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'],
      email: json['email'],
      role: json['role'],
      fullName: json['full_name'],
    );
  }
}

class LoginResponse {
  String? token;
  UserInfo? user;

  LoginResponse({this.token, this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['access_token'],
      user: json['user'] != null ? UserInfo.fromJson(json['user']) : null,
    );  
  }
}
