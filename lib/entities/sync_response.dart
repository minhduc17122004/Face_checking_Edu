class IOResult {
  final int ioId;
  final bool success;
  final int code;
  final String? error;
  final int status;

  const IOResult({
    required this.ioId,
    required this.success,
    required this.code,
    this.error,
    required this.status,
  });

  factory IOResult.fromJson(Map<String, dynamic> json) => IOResult(
        ioId: (json['io_id'] ?? 0) as int,
        success: (json['success'] ?? false) as bool,
        code: (json['code'] ?? 0) as int,
        error: json['error'] as String?,
        status: (json['status'] ?? 0) as int,
      );

  Map<String, dynamic> toJson() => {
        'io_id': ioId,
        'success': success,
        'code': code,
        'error': error,
        'status': status,
      };
}

class SyncResponse {
  final int employeeId;
  final String pin;
  final bool success;
  final String message;
  final List<IOResult> iOResults;
  final int status;

  const SyncResponse({
    required this.employeeId,
    required this.pin,
    required this.success,
    required this.message,
    required this.iOResults,
    required this.status,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) => SyncResponse(
        employeeId: json['employee_id'] as int,
        pin: (json['pin'] ?? '').toString(),
        success: json['success'] as bool,
        message: json['message'] ?? '',
        iOResults: (json['io_results'] as List<dynamic>? ?? [])
            .map((e) => IOResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        status: json['status'] as int,
      );
}
