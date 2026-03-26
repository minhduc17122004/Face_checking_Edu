class AttendanceConfig {
  final String id;
  final String sessionId;
  final int earlyAllowance;
  final int lateAllowance;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AttendanceConfig({
    required this.id,
    required this.sessionId,
    this.earlyAllowance = 15,
    this.lateAllowance = 15,
    required this.createdAt,
    this.updatedAt,
  });

  factory AttendanceConfig.fromJson(Map<String, dynamic> json) {
    return AttendanceConfig(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      earlyAllowance: json['early_allowance'] as int? ?? 15,
      lateAllowance: json['late_allowance'] as int? ?? 15,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'early_allowance': earlyAllowance,
      'late_allowance': lateAllowance,
    };
  }

  AttendanceConfig copyWith({
    String? id,
    String? sessionId,
    int? earlyAllowance,
    int? lateAllowance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceConfig(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      earlyAllowance: earlyAllowance ?? this.earlyAllowance,
      lateAllowance: lateAllowance ?? this.lateAllowance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'AttendanceConfig(sessionId: $sessionId, early: ${earlyAllowance}m, late: ${lateAllowance}m)';
}
