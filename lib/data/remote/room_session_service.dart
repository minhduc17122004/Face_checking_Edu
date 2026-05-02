import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/room_session.dart';
import '../../entities/room.dart';
import '../../entities/course.dart';
import 'api_endpoint.dart';

class EligibleRoomSessionResult {
  const EligibleRoomSessionResult({
    this.session,
    this.status,
    this.message,
  });

  final RoomSession? session;
  final String? status;
  final String? message;
}

abstract class RoomSessionService {
  Future<DataState<List<Room>>> getRooms({int? limit, int? offset});
  Future<DataState<List<RoomSession>>> getRoomSessions(
    String roomId, {
    DateTime? sessionDate,
    int skip = 0,
    int limit = 100,
  });

  /// Returns the single active session for [roomId], or null if none.
  Future<DataState<RoomSession?>> getActiveRoomSession(String roomId);
  Future<DataState<EligibleRoomSessionResult>> getEligibleCheckinSession(
    String roomId,
  );
  Future<DataState<List<Course>>> getRoomCourses(String roomId);
  Future<DataState<void>> activateSession(String sessionId);
  Future<DataState<void>> closeSession(String sessionId);
  Future<DataState<Map<String, dynamic>>> getSessionStatus(String sessionId);
}

@LazySingleton(as: RoomSessionService)
class RoomSessionServiceImplement implements RoomSessionService {
  RoomSessionServiceImplement(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<DataState<List<Room>>> getRooms({int? limit, int? offset}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['skip'] = offset;

      final response = await _apiClient.get(
        path: ApiEndpoint.rooms,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>? ?? [];
        return DataSuccess<List<Room>>(
          items.map((e) => Room.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return DataFailed<List<Room>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getRooms: $e');
      return DataFailed<List<Room>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getRooms: $e');
      return DataFailed<List<Room>>(e.toString());
    }
  }

  @override
  Future<DataState<List<RoomSession>>> getRoomSessions(
    String roomId, {
    DateTime? sessionDate,
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final path = ApiEndpoint.roomSessions.replaceAll('{id}', roomId);
      final queryParams = <String, dynamic>{
        'skip': skip,
        'limit': limit,
      };
      if (sessionDate != null) {
        queryParams['session_date'] =
            '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}';
      }

      final response = await _apiClient.get(
        path: path,
        queryParameters: queryParams,
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>? ?? [];
        return DataSuccess<List<RoomSession>>(
          items
              .map((e) => RoomSession.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
      return DataFailed<List<RoomSession>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getRoomSessions: $e');
      return DataFailed<List<RoomSession>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getRoomSessions: $e');
      return DataFailed<List<RoomSession>>(e.toString());
    }
  }

  @override
  Future<DataState<RoomSession?>> getActiveRoomSession(String roomId) async {
    try {
      final path = ApiEndpoint.roomActiveSession.replaceAll('{id}', roomId);
      final response = await _apiClient.get(path: path);
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final sessionJson = json['session'];
        if (sessionJson == null) {
          return const DataSuccess<RoomSession?>(null);
        }
        return DataSuccess<RoomSession?>(
          RoomSession.fromJson(sessionJson as Map<String, dynamic>),
        );
      }
      return DataFailed<RoomSession?>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getActiveRoomSession: $e');
      return DataFailed<RoomSession?>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getActiveRoomSession: $e');
      return DataFailed<RoomSession?>(e.toString());
    }
  }

  @override
  Future<DataState<EligibleRoomSessionResult>> getEligibleCheckinSession(
    String roomId,
  ) async {
    try {
      final path =
          ApiEndpoint.roomEligibleCheckinSession.replaceAll('{id}', roomId);
      final response = await _apiClient.dio.get<dynamic>(
        path,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 404 || response.statusCode == 405) {
        return DataFailed<EligibleRoomSessionResult>(
          'Eligible check-in endpoint is not available',
          code: response.statusCode,
        );
      }

      final data = response.data;
      if (response.statusCode == null || response.statusCode! >= 400) {
        return DataFailed<EligibleRoomSessionResult>(
          _extractErrorMessage(data) ?? 'Failed to load eligible session',
          code: response.statusCode,
        );
      }

      if (data is! Map<String, dynamic>) {
        return const DataFailed<EligibleRoomSessionResult>(
          'Invalid eligible session response',
        );
      }

      final sessionJson = data['session'] ?? data['data'];
      final session = sessionJson is Map<String, dynamic>
          ? RoomSession.fromJson(sessionJson)
          : null;

      return DataSuccess<EligibleRoomSessionResult>(
        EligibleRoomSessionResult(
          session: session,
          status: data['status'] as String?,
          message: data['message'] as String?,
        ),
      );
    } on DioError catch (e) {
      await pushLog('Error in getEligibleCheckinSession: $e');
      return DataFailed<EligibleRoomSessionResult>(
        e.message,
        code: e.response?.statusCode,
      );
    } on Exception catch (e) {
      await pushLog('Error in getEligibleCheckinSession: $e');
      return DataFailed<EligibleRoomSessionResult>(e.toString());
    }
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final message = data['message'] ?? data['detail'] ?? data['error'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    return null;
  }

  @override
  Future<DataState<List<Course>>> getRoomCourses(String roomId) async {
    try {
      final path = ApiEndpoint.roomCourses.replaceAll('{id}', roomId);
      final response = await _apiClient.get(path: path);
      if (response.isSuccess()) {
        final json = response.data as List<dynamic>;
        return DataSuccess<List<Course>>(
          json.map((e) => Course.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return DataFailed<List<Course>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getRoomCourses: $e');
      return DataFailed<List<Course>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getRoomCourses: $e');
      return DataFailed<List<Course>>(e.toString());
    }
  }

  @override
  Future<DataState<void>> activateSession(String sessionId) async {
    try {
      final path = ApiEndpoint.sessionActivate.replaceAll('{id}', sessionId);
      final response = await _apiClient.post(path: path);
      if (response.isSuccess()) {
        return const DataSuccess<void>(null);
      }
      return DataFailed<void>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in activateSession: $e');
      return DataFailed<void>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in activateSession: $e');
      return DataFailed<void>(e.toString());
    }
  }

  @override
  Future<DataState<void>> closeSession(String sessionId) async {
    try {
      final path = ApiEndpoint.sessionClose.replaceAll('{id}', sessionId);
      final response = await _apiClient.post(path: path);
      if (response.isSuccess()) {
        return const DataSuccess<void>(null);
      }
      return DataFailed<void>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in closeSession: $e');
      return DataFailed<void>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in closeSession: $e');
      return DataFailed<void>(e.toString());
    }
  }

  @override
  Future<DataState<Map<String, dynamic>>> getSessionStatus(
      String sessionId) async {
    try {
      final path = ApiEndpoint.sessionStatus.replaceAll('{id}', sessionId);
      final response = await _apiClient.get(path: path);
      if (response.isSuccess()) {
        return DataSuccess<Map<String, dynamic>>(
          (response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Map<String, dynamic>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getSessionStatus: $e');
      return DataFailed<Map<String, dynamic>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getSessionStatus: $e');
      return DataFailed<Map<String, dynamic>>(e.toString());
    }
  }
}
