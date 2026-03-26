import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/attendance_record_ui.dart';
import 'api_endpoint.dart';

class ManualCheckinResult {
  final String attendanceId;
  final int studentId;
  final String sessionId;
  final String status;
  final DateTime checkinTime;
  final int? minutesDiff;
  final String message;

  const ManualCheckinResult({
    required this.attendanceId,
    required this.studentId,
    required this.sessionId,
    required this.status,
    required this.checkinTime,
    this.minutesDiff,
    required this.message,
  });

  factory ManualCheckinResult.fromJson(Map<String, dynamic> json) {
    return ManualCheckinResult(
      attendanceId: json['attendance_id'] as String,
      studentId: json['student_id'] as int,
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
      checkinTime: DateTime.parse(json['checkin_time'] as String),
      minutesDiff: json['minutes_diff'] as int?,
      message: json['message'] as String,
    );
  }
}

class AttendanceCheckinSummary {
  final String sessionId;
  final String courseName;
  final int totalEnrolled;
  final int totalCheckedIn;
  final int present;   // deprecated alias for on_time
  final int early;
  final int onTime;
  final int late;
  final int absent;
  final double attendanceRate;

  const AttendanceCheckinSummary({
    required this.sessionId,
    required this.courseName,
    required this.totalEnrolled,
    required this.totalCheckedIn,
    required this.present,
    required this.early,
    required this.onTime,
    required this.late,
    required this.absent,
    required this.attendanceRate,
  });

  factory AttendanceCheckinSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceCheckinSummary(
      sessionId: json['session_id'] as String,
      courseName: json['course_name'] as String,
      totalEnrolled: json['total_enrolled'] as int? ?? 0,
      totalCheckedIn: json['total_checked_in'] as int? ?? 0,
      present: json['present'] as int? ?? 0,
      early: json['early'] as int? ?? 0,
      onTime: json['on_time'] as int? ?? 0,
      late: json['late'] as int? ?? 0,
      absent: json['absent'] as int? ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

abstract class AttendanceCheckinService {
  Future<DataState<ManualCheckinResult>> manualCheckin({
    required String sessionId,
    required int studentId,
    DateTime? checkinTime,
    String status = 'present',
    String? deviceId,
  });
  Future<DataState<List<AttendanceRecordUI>>> getSessionCheckins(
    String sessionId, {
    int skip = 0,
    int limit = 1000,
  });
  Future<DataState<AttendanceCheckinSummary>> getSessionSummary(String sessionId);
}

@LazySingleton(as: AttendanceCheckinService)
class AttendanceCheckinServiceImplement implements AttendanceCheckinService {
  AttendanceCheckinServiceImplement(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<DataState<ManualCheckinResult>> manualCheckin({
    required String sessionId,
    required int studentId,
    DateTime? checkinTime,
    String status = 'present',
    String? deviceId,
  }) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.attendanceCheckin,
        data: {
          'session_id': sessionId,
          'student_id': studentId,
          if (checkinTime != null) 'checkin_time': checkinTime.toIso8601String(),
          'status': status,
          if (deviceId != null) 'device_id': deviceId,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<ManualCheckinResult>(
          ManualCheckinResult.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<ManualCheckinResult>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in manualCheckin: $e');
      return DataFailed<ManualCheckinResult>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in manualCheckin: $e');
      return DataFailed<ManualCheckinResult>(e.toString());
    }
  }

  @override
  Future<DataState<List<AttendanceRecordUI>>> getSessionCheckins(
    String sessionId, {
    int skip = 0,
    int limit = 1000,
  }) async {
    try {
      final path = ApiEndpoint.attendanceSessionCheckins.replaceAll('{id}', sessionId);
      final response = await _apiClient.get(
        path: path,
        queryParameters: {'skip': skip, 'limit': limit},
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>? ?? [];
        return DataSuccess<List<AttendanceRecordUI>>(
          items.map((e) => AttendanceRecordUI.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return DataFailed<List<AttendanceRecordUI>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getSessionCheckins: $e');
      return DataFailed<List<AttendanceRecordUI>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getSessionCheckins: $e');
      return DataFailed<List<AttendanceRecordUI>>(e.toString());
    }
  }

  @override
  Future<DataState<AttendanceCheckinSummary>> getSessionSummary(String sessionId) async {
    try {
      final path = ApiEndpoint.attendanceSessionSummary.replaceAll('{id}', sessionId);
      final response = await _apiClient.get(path: path);
      if (response.isSuccess()) {
        return DataSuccess<AttendanceCheckinSummary>(
          AttendanceCheckinSummary.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<AttendanceCheckinSummary>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getSessionSummary: $e');
      return DataFailed<AttendanceCheckinSummary>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getSessionSummary: $e');
      return DataFailed<AttendanceCheckinSummary>(e.toString());
    }
  }
}
