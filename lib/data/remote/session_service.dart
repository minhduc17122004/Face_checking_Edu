import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/api_response.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/session.dart';
import 'api_endpoint.dart';

abstract class SessionService {
  Future<DataState<List<Session>>> getSessions({
    String? courseId,
    DateTime? date,
    String? status,
    int? limit,
    int? offset,
  });
  Future<DataState<Session>> getSession(String id);
  Future<DataState<Session>> createSession({
    required String courseId,
    String? scheduleId,
    required DateTime sessionDate,
    required DateTime startTime,
    DateTime? endTime,
    DateTime? checkinWindowStart,
    DateTime? checkinWindowEnd,
    String status = 'scheduled',
  });
  Future<DataState<Session>> updateSession(
    String id, {
    String? status,
    DateTime? endTime,
    DateTime? checkinWindowStart,
    DateTime? checkinWindowEnd,
  });
  Future<DataState<void>> deleteSession(String id);
  Future<DataState<SessionSummary>> getSessionSummary(String id);
  Future<DataState<Session>> activateSession(String id);
  Future<DataState<Session>> closeSession(String id);
  Future<DataState<Map<String, dynamic>>> generateDailySessions(
      DateTime date);
  Future<DataState<Session>> getTeacherActiveOrNextSession();
  Future<DataState<List<Session>>> getTeacherSessions({
    DateTime? date,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? limit,
    int? offset,
  });
  Future<DataState<List<Session>>> getAdminSessions({
    DateTime? date,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? limit,
    int? offset,
  });
}

@LazySingleton(as: SessionService)
class SessionServiceImplement implements SessionService {
  SessionServiceImplement(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DataState<List<Session>>> getSessions({
    String? courseId,
    DateTime? date,
    String? status,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (courseId != null) queryParams['course_id'] = courseId;
      if (date != null) {
        queryParams['session_date'] =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
      if (status != null) queryParams['status'] = status;
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['skip'] = offset;

      final ApiResponse response = await _apiClient.get(
        path: ApiEndpoint.sessions,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>;
        final sessions = items
            .map((e) => Session.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<Session>>(sessions);
      }
      return DataFailed<List<Session>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getSessions: $e');
      return DataFailed<List<Session>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getSessions: $e');
      return DataFailed<List<Session>>(e.toString());
    }
  }

  @override
  Future<DataState<Session>> getSession(String id) async {
    try {
      final response = await _apiClient.get(path: '${ApiEndpoint.sessions}/$id');
      if (response.isSuccess()) {
        return DataSuccess<Session>(
          Session.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Session>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getSession: $e');
      return DataFailed<Session>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getSession: $e');
      return DataFailed<Session>(e.toString());
    }
  }

  @override
  Future<DataState<Session>> createSession({
    required String courseId,
    String? scheduleId,
    required DateTime sessionDate,
    required DateTime startTime,
    DateTime? endTime,
    DateTime? checkinWindowStart,
    DateTime? checkinWindowEnd,
    String status = 'scheduled',
  }) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.sessions,
        data: {
          'course_id': courseId,
          if (scheduleId != null) 'schedule_id': scheduleId,
          'session_date':
              '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}',
          'start_time': startTime.toIso8601String(),
          if (endTime != null) 'end_time': endTime.toIso8601String(),
          if (checkinWindowStart != null)
            'checkin_window_start': checkinWindowStart.toIso8601String(),
          if (checkinWindowEnd != null)
            'checkin_window_end': checkinWindowEnd.toIso8601String(),
          'status': status,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<Session>(
          Session.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Session>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in createSession: $e');
      return DataFailed<Session>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in createSession: $e');
      return DataFailed<Session>(e.toString());
    }
  }

  @override
  Future<DataState<Session>> updateSession(
    String id, {
    String? status,
    DateTime? endTime,
    DateTime? checkinWindowStart,
    DateTime? checkinWindowEnd,
  }) async {
    try {
      final response = await _apiClient.patch(
        path: '${ApiEndpoint.sessions}/$id',
        data: {
          if (status != null) 'status': status,
          if (endTime != null) 'end_time': endTime.toIso8601String(),
          if (checkinWindowStart != null)
            'checkin_window_start': checkinWindowStart.toIso8601String(),
          if (checkinWindowEnd != null)
            'checkin_window_end': checkinWindowEnd.toIso8601String(),
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<Session>(
          Session.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Session>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in updateSession: $e');
      return DataFailed<Session>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in updateSession: $e');
      return DataFailed<Session>(e.toString());
    }
  }

  @override
  Future<DataState<void>> deleteSession(String id) async {
    try {
      final response =
          await _apiClient.delete(path: '${ApiEndpoint.sessions}/$id');
      if (response.isSuccess()) {
        return const DataSuccess<void>(null);
      }
      return DataFailed<void>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in deleteSession: $e');
      return DataFailed<void>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in deleteSession: $e');
      return DataFailed<void>(e.toString());
    }
  }

  @override
  Future<DataState<SessionSummary>> getSessionSummary(String id) async {
    try {
      final response = await _apiClient.get(
        path: ApiEndpoint.sessionSummary.replaceFirst('{id}', id),
      );
      if (response.isSuccess()) {
        return DataSuccess<SessionSummary>(
          SessionSummary.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<SessionSummary>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getSessionSummary: $e');
      return DataFailed<SessionSummary>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getSessionSummary: $e');
      return DataFailed<SessionSummary>(e.toString());
    }
  }

  @override
  Future<DataState<Session>> activateSession(String id) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.sessionActivate.replaceFirst('{id}', id),
      );
      if (response.isSuccess()) {
        final data = response.data as Map<String, dynamic>;
        // If the backend returns just {session_id, status}, we might need to fetch the full session
        // but often the backend is updated to return more.
        // For now, let's assume it returns enough or handle it.
        if (data.containsKey('session_id') && !data.containsKey('id')) {
          return getSession(id);
        }
        return DataSuccess<Session>(
          Session.fromJson(data),
        );
      }
      return DataFailed<Session>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in activateSession: $e');
      return DataFailed<Session>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in activateSession: $e');
      return DataFailed<Session>(e.toString());
    }
  }

  @override
  Future<DataState<Session>> closeSession(String id) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.sessionClose.replaceFirst('{id}', id),
      );
      if (response.isSuccess()) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('session_id') && !data.containsKey('id')) {
          return getSession(id);
        }
        return DataSuccess<Session>(
          Session.fromJson(data),
        );
      }
      return DataFailed<Session>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in closeSession: $e');
      return DataFailed<Session>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in closeSession: $e');
      return DataFailed<Session>(e.toString());
    }
  }

  @override
  Future<DataState<Map<String, dynamic>>> generateDailySessions(
      DateTime date) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.sessionGenerateDaily,
        queryParameters: {
          'target_date':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<Map<String, dynamic>>(
            response.data as Map<String, dynamic>);
      }
      return DataFailed<Map<String, dynamic>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in generateDailySessions: $e');
      return DataFailed<Map<String, dynamic>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in generateDailySessions: $e');
      return DataFailed<Map<String, dynamic>>(e.toString());
    }
  }

  @override
  Future<DataState<Session>> getTeacherActiveOrNextSession() async {
    try {
      final response = await _apiClient.get(
        path: ApiEndpoint.sessionTeacherActiveOrNext,
      );
      if (response.isSuccess()) {
        final data = response.data as Map<String, dynamic>;
        if (data['session'] == null) {
          return DataFailed<Session>('No active or upcoming session found.');
        }

        // The endpoint returns { session, status, mode, can_open, can_close }
        // We need to merge these into the Session object
        final sessionData = data['session'] as Map<String, dynamic>;
        sessionData['mapped_status'] = data['status'];
        sessionData['mode'] = data['mode'];
        sessionData['can_open'] = data['can_open'];
        sessionData['can_close'] = data['can_close'];

        return DataSuccess<Session>(
          Session.fromJson(sessionData),
        );
      }
      return DataFailed<Session>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getTeacherActiveOrNextSession: $e');
      return DataFailed<Session>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getTeacherActiveOrNextSession: $e');
      return DataFailed<Session>(e.toString());
    }
  }

  @override
  Future<DataState<List<Session>>> getTeacherSessions({
    DateTime? date,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (dateFrom != null && dateTo != null) {
        // Ưu tiên khoảng ngày nếu được cung cấp
        queryParams['date_from'] =
            '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
        queryParams['date_to'] =
            '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      } else if (date != null) {
        queryParams['session_date'] =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['skip'] = offset;

      final ApiResponse response = await _apiClient.get(
        path: ApiEndpoint.sessionTeacher,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>;
        final sessions = items
            .map((e) => Session.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<Session>>(sessions);
      }
      return DataFailed<List<Session>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getTeacherSessions: $e');
      return DataFailed<List<Session>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getTeacherSessions: $e');
      return DataFailed<List<Session>>(e.toString());
    }
  }
  @override
  Future<DataState<List<Session>>> getAdminSessions({
    DateTime? date,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (dateFrom != null && dateTo != null) {
        queryParams['date_from'] =
            '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
        queryParams['date_to'] =
            '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      } else if (date != null) {
        queryParams['session_date'] =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['skip'] = offset;

      final ApiResponse response = await _apiClient.get(
        path: ApiEndpoint.sessionAdmin,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>;
        final sessions = items
            .map((e) => Session.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<Session>>(sessions);
      }
      return DataFailed<List<Session>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getAdminSessions: $e');
      return DataFailed<List<Session>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getAdminSessions: $e');
      return DataFailed<List<Session>>(e.toString());
    }
  }
}
