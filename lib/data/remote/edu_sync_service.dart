import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/entities/pending_edu_check_in.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/data_state.dart';
import 'api_endpoint.dart';

/// Result for a single item in a bulk check-in response.
class BulkCheckinItemResult {
  final String localId;
  final bool success;
  final String? attendanceId;
  final String? error;
  final bool skipped;

  const BulkCheckinItemResult({
    required this.localId,
    required this.success,
    this.attendanceId,
    this.error,
    this.skipped = false,
  });

  factory BulkCheckinItemResult.fromJson(Map<String, dynamic> json) {
    return BulkCheckinItemResult(
      localId: json['local_id'] as String,
      success: json['success'] as bool,
      attendanceId: json['attendance_id'] as String?,
      error: json['error'] as String?,
      skipped: json['skipped'] as bool? ?? false,
    );
  }
}

/// Aggregated result of a bulk check-in sync operation.
class EduSyncResult {
  final int total;
  final int succeeded;
  final int failed;
  final int skipped;
  final List<BulkCheckinItemResult> results;

  const EduSyncResult({
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.skipped,
    required this.results,
  });

  factory EduSyncResult.fromJson(Map<String, dynamic> json) {
    final items = (json['results'] as List<dynamic>?) ?? [];
    return EduSyncResult(
      total: json['total'] as int? ?? 0,
      succeeded: json['succeeded'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      skipped: json['skipped'] as int? ?? 0,
      results: items
          .map((e) =>
              BulkCheckinItemResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Returns the localIds successfully synced (including skipped duplicates).
  List<String> get syncedLocalIds => results
      .where((r) => r.success)
      .map((r) => r.localId)
      .toList();
}

/// Service for syncing offline [PendingEduCheckIn] records to the backend
/// via the `POST /api/v1/attendance/bulk-check-in` endpoint.
abstract class EduSyncService {
  Future<DataState<EduSyncResult>> syncPendingCheckIns(
    List<PendingEduCheckIn> items,
  );
}

@LazySingleton(as: EduSyncService)
class EduSyncServiceImpl implements EduSyncService {
  EduSyncServiceImpl(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<DataState<EduSyncResult>> syncPendingCheckIns(
    List<PendingEduCheckIn> items,
  ) async {
    try {
      if (items.isEmpty) {
        return DataSuccess<EduSyncResult>(EduSyncResult(
          total: 0,
          succeeded: 0,
          failed: 0,
          skipped: 0,
          results: [],
        ));
      }

      final payload = {
        'items': items.map((item) => _itemToJson(item)).toList(),
      };

      final response = await _apiClient.post(
        path: ApiEndpoint.attendanceBulkCheckin,
        data: payload,
      );

      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        return DataSuccess<EduSyncResult>(EduSyncResult.fromJson(json));
      }
      return DataFailed<EduSyncResult>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in syncPendingCheckIns (DioError): $e');
      return DataFailed<EduSyncResult>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in syncPendingCheckIns: $e');
      return DataFailed<EduSyncResult>(e.toString());
    }
  }

  Map<String, dynamic> _itemToJson(PendingEduCheckIn item) {
    final m = <String, dynamic>{
      'local_id': item.localId,
      'student_id': item.studentId,
      'timestamp': item.timestamp.toUtc().toIso8601String(),
    };
    if (item.sessionId != null) {
      m['session_id'] = item.sessionId;
    }
    if (item.roomId != null) {
      m['room_id'] = item.roomId;
    }
    if (item.deviceId != null) {
      m['device_id'] = item.deviceId;
    }
    if (item.serverUserId != null) {
      m['server_user_id'] = item.serverUserId;
    }
    if (item.pin != null) {
      m['pin'] = item.pin;
    }
    if (item.minutesLate != null) {
      m['minutes_diff'] = item.minutesLate;
    }
    if (item.status != null) {
      m['status'] = item.status;
    }
    if (item.isSpoof) {
      m['is_spoof'] = true;
    }
    return m;
  }
}
