import 'dart:io';

import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/data_state.dart';
import 'api_endpoint.dart';

/// Entity for a single attendance history item.
class AttendanceHistoryItem {
  final String id;
  final int studentId;
  final String? studentName;
  final String? studentCode;
  final String sessionId;
  final DateTime? sessionDate;
  final String? courseName;
  final String? courseId;
  final String? roomName;
  final DateTime checkinTime;
  final String status;
  final int? minutesDiff;

  const AttendanceHistoryItem({
    required this.id,
    required this.studentId,
    this.studentName,
    this.studentCode,
    required this.sessionId,
    this.sessionDate,
    this.courseName,
    this.courseId,
    this.roomName,
    required this.checkinTime,
    required this.status,
    this.minutesDiff,
  });

  factory AttendanceHistoryItem.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryItem(
      id: json['id'] as String,
      studentId: json['student_id'] as int,
      studentName: json['student_name'] as String?,
      studentCode: json['student_code'] as String?,
      sessionId: json['session_id'] as String,
      sessionDate: json['session_date'] != null
          ? DateTime.parse(json['session_date'] as String)
          : null,
      courseName: json['course_name'] as String?,
      courseId: json['course_id'] as String?,
      roomName: json['room_name'] as String?,
      checkinTime: DateTime.parse(json['checkin_time'] as String),
      status: json['status'] as String,
      minutesDiff: json['minutes_diff'] as int?,
    );
  }

  /// Vietnamese status label.
  String get statusLabel {
    switch (status) {
      case 'early':
        return 'Sớm';
      case 'on_time':
        return 'Đúng giờ';
      case 'late':
        return 'Trễ';
      case 'present':
        return 'Có mặt';
      case 'absent':
        return 'Vắng';
      default:
        return status;
    }
  }
}

/// Service for fetching attendance history from the API.
abstract class AttendanceHistoryService {
  Future<DataState<List<AttendanceHistoryItem>>> getHistory({
    String? courseId,
    int skip = 0,
    int limit = 50,
  });

  Future<DataState<String>> downloadExportFile({
    String? courseId,
    DateTime? fromDate,
    DateTime? toDate,
    required String format,
    String? courseName,
  });
}

@LazySingleton(as: AttendanceHistoryService)
class AttendanceHistoryServiceImpl implements AttendanceHistoryService {
  AttendanceHistoryServiceImpl(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<DataState<List<AttendanceHistoryItem>>> getHistory({
    String? courseId,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _apiClient.get(
        path: ApiEndpoint.attendanceHistory,
        queryParameters: {
          if (courseId != null) 'course_id': courseId,
          'skip': skip,
          'limit': limit,
        },
      );
      
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>? ?? [];
        return DataSuccess<List<AttendanceHistoryItem>>(
          items.map((e) => AttendanceHistoryItem.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return DataFailed<List<AttendanceHistoryItem>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getHistory: \$e');
      return DataFailed<List<AttendanceHistoryItem>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getHistory: \$e');
      return DataFailed<List<AttendanceHistoryItem>>(e.toString());
    }
  }

  @override
  Future<DataState<String>> downloadExportFile({
    String? courseId,
    DateTime? fromDate,
    DateTime? toDate,
    required String format,
    String? courseName,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${dir.path}/temp_export_$timestamp';

      final response = await _apiClient.download(
        path: ApiEndpoint.attendanceExport,
        savePath: tempPath,
        queryParameters: {
          'format': format,
          if (courseId != null) 'course_id': courseId,
          if (fromDate != null) 'from_date': fromDate.toIso8601String().split('T').first,
          if (toDate != null) 'to_date': toDate.toIso8601String().split('T').first,
        },
      );

      if (response.isSuccess()) {
        final tempFile = File(tempPath);
        if (await tempFile.exists() && (await tempFile.length()) > 0) {
          // Identify real extension from content-type header
          final contentType = response.data?.toString().toLowerCase() ?? '';
          String realExt = format == 'excel' ? 'xlsx' : 'csv';
          
          if (contentType.contains('spreadsheetml') || contentType.contains('excel')) {
            realExt = 'xlsx';
          } else if (contentType.contains('csv')) {
            realExt = 'csv';
          }

          final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final safeName = (courseName ?? 'TatCa')
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .replaceAll(' ', '_');
          final finalFileName = 'Diem_Danh_${safeName}_$dateStr.$realExt';
          final finalPath = '${dir.path}/$finalFileName';

          final savedFile = await tempFile.rename(finalPath);
          return DataSuccess<String>(savedFile.path);
        }
        return const DataFailed<String>('File tải về bị rỗng');
      }
      return DataFailed<String>(response.error ?? 'Download thất bại');
    } on DioError catch (e) {
      return DataFailed<String>(e.message ?? 'Lỗi kết nối');
    } catch (e) {
      return DataFailed<String>(e.toString());
    }
  }
}
