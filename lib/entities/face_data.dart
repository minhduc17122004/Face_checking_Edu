class FaceData {
  final int empId;
  final DateTime updatedTime;
  final List<List<double>> listFaceEmbedding;
  String? personName;

  FaceData(
      {required this.empId,
      required this.updatedTime,
      required this.listFaceEmbedding,
      this.personName});

  factory FaceData.fromJson(Map<String, dynamic> json) {
    return FaceData(
        empId: json['empId'],
        updatedTime: DateTime.parse(json['updatedTime']),
        listFaceEmbedding: (json['listFaceEmbedding'] as List)
            .map((item) => (item as List).cast<double>())
            .toList(),
        personName: json['personName']);
  }
  Map<String, dynamic> toJson() {
    return {
      'empId': empId,
      'updatedTime': updatedTime.toIso8601String().split('.').first,
      'listFaceEmbedding': listFaceEmbedding,
      'personName': personName,
    };
  }
}
