class LoginRequest {
  String? username;
  String? password;
 String? database;

  LoginRequest({
    this.username,
    this.password,
    this.database,
  });

  Map<String, dynamic> toJson() {
    return {
      'login': username,
      'password': password,
      'db': database,
    };
  }
}
