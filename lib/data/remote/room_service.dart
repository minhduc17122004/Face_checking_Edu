import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/api_response.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/room.dart';
import 'api_endpoint.dart';

abstract class RoomService {
  Future<DataState<List<Room>>> getRooms({int? limit, int? offset});
  Future<DataState<Room>> getRoom(String id);
  Future<DataState<Room>> createRoom({
    String? code,
    required String name,
    String? building,
    int? floor,
    int? capacity,
  });
  Future<DataState<Room>> updateRoom(
    String id, {
    String? code,
    String? name,
    String? building,
    int? floor,
    int? capacity,
  });
  Future<DataState<void>> deleteRoom(String id);
}

@LazySingleton(as: RoomService)
class RoomServiceImplement implements RoomService {
  RoomServiceImplement(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DataState<List<Room>>> getRooms({int? limit, int? offset}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['skip'] = offset;

      final ApiResponse response = await _apiClient.get(
        path: ApiEndpoint.rooms,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>;
        final rooms = items
            .map((e) => Room.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<Room>>(rooms);
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
  Future<DataState<Room>> getRoom(String id) async {
    try {
      final response = await _apiClient.get(path: '${ApiEndpoint.rooms}/$id');
      if (response.isSuccess()) {
        return DataSuccess<Room>(
          Room.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Room>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getRoom: $e');
      return DataFailed<Room>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getRoom: $e');
      return DataFailed<Room>(e.toString());
    }
  }

  @override
  Future<DataState<Room>> createRoom({
    String? code,
    required String name,
    String? building,
    int? floor,
    int? capacity,
  }) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.rooms,
        data: {
          if (code != null) 'code': code,
          'name': name,
          if (building != null) 'building': building,
          if (floor != null) 'floor': floor,
          if (capacity != null) 'capacity': capacity,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<Room>(
          Room.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Room>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in createRoom: $e');
      return DataFailed<Room>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in createRoom: $e');
      return DataFailed<Room>(e.toString());
    }
  }

  @override
  Future<DataState<Room>> updateRoom(
    String id, {
    String? code,
    String? name,
    String? building,
    int? floor,
    int? capacity,
  }) async {
    try {
      final response = await _apiClient.put(
        path: '${ApiEndpoint.rooms}/$id',
        data: {
          if (code != null) 'code': code,
          if (name != null) 'name': name,
          if (building != null) 'building': building,
          if (floor != null) 'floor': floor,
          if (capacity != null) 'capacity': capacity,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<Room>(
          Room.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Room>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in updateRoom: $e');
      return DataFailed<Room>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in updateRoom: $e');
      return DataFailed<Room>(e.toString());
    }
  }

  @override
  Future<DataState<void>> deleteRoom(String id) async {
    try {
      final response = await _apiClient.delete(path: '${ApiEndpoint.rooms}/$id');
      if (response.isSuccess()) {
        return const DataSuccess<void>(null);
      }
      return DataFailed<void>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in deleteRoom: $e');
      return DataFailed<void>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in deleteRoom: $e');
      return DataFailed<void>(e.toString());
    }
  }
}
