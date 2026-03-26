import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/room_session.dart';
import '../../entities/room.dart';
import '../../entities/course.dart';
import 'api_endpoint.dart';

abstract class RoomSessionService {
  Future<DataState<List<Room>>> getRooms({int? limit, int? offset});
  Future<DataState<List<RoomSession>>> getRoomSessions(
    String roomId, {
    DateTime? sessionDate,
    int skip = 0,
    int limit = 100,
  });
  Future<DataState<List<Course>>> getRoomCourses(String roomId);
  Future<DataState<void>> activateSession(String sessionId);
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
          items.map((e) => RoomSession.fromJson(e as Map<String, dynamic>)).toList(),
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
      final path = '${ApiEndpoint.sessions}$sessionId';
      final response = await _apiClient.put(
        path: path,
        data: {'status': 'active'},
      );
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
}
