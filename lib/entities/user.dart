class User {
  int? id;
  String? barcode;
  String? name;
  String? employeeCode;
  String? jobTitle;

  User({
    this.id,
    this.barcode,
    this.name,
    this.employeeCode,
    this.jobTitle,
  });

  User copyWith({
    int? id,
    String? barcode,
    String? name,
    String? employeeCode,
    String? jobTitle,
  }) {
    return User(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      employeeCode: employeeCode ?? this.employeeCode,
      jobTitle: jobTitle ?? this.jobTitle,
    );
  }
}
