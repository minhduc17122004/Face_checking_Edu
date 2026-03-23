import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/api_response.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/time_slot.dart';
import 'api_endpoint.dart';

abstract class TimeSlotService {
  Future<DataState<List<TimeSlot>>> getTimeSlots({int? limit, int? offset});
  Future<DataState<TimeSlot>> getTimeSlot(int id);
  Future<DataState<TimeSlot>> createTimeSlot({
    required int periodNumber,
    required String startTime,
    required String endTime,
  });
  Future<DataState<TimeSlot>> updateTimeSlot(
    int id, {
    int? periodNumber,
    String? startTime,
    String? endTime,
  });
  Future<DataState<void>> deleteTimeSlot(int id);
}

@LazySingleton(as: TimeSlotService)
class TimeSlotServiceImplement implements TimeSlotService {
  TimeSlotServiceImplement(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DataState<List<TimeSlot>>> getTimeSlots({
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['skip'] = offset;

      final ApiResponse response = await _apiClient.get(
        path: ApiEndpoint.timeSlots,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = (json['items'] as List<dynamic>? ?? const []);
        final slots = items
            .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<TimeSlot>>(slots);
      }
      return DataFailed<List<TimeSlot>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getTimeSlots: $e');
      return DataFailed<List<TimeSlot>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getTimeSlots: $e');
      return DataFailed<List<TimeSlot>>(e.toString());
    }
  }

  @override
  Future<DataState<TimeSlot>> getTimeSlot(int id) async {
    try {
      final response = await _apiClient.get(
        path: '${ApiEndpoint.timeSlots}/$id',
      );
      if (response.isSuccess()) {
        return DataSuccess<TimeSlot>(
          TimeSlot.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<TimeSlot>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getTimeSlot: $e');
      return DataFailed<TimeSlot>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getTimeSlot: $e');
      return DataFailed<TimeSlot>(e.toString());
    }
  }

  @override
  Future<DataState<TimeSlot>> createTimeSlot({
    required int periodNumber,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.timeSlots,
        data: {
          'period_number': periodNumber,
          'start_time': startTime,
          'end_time': endTime,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<TimeSlot>(
          TimeSlot.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<TimeSlot>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in createTimeSlot: $e');
      return DataFailed<TimeSlot>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in createTimeSlot: $e');
      return DataFailed<TimeSlot>(e.toString());
    }
  }

  @override
  Future<DataState<TimeSlot>> updateTimeSlot(
    int id, {
    int? periodNumber,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (periodNumber != null) data['period_number'] = periodNumber;
      if (startTime != null) data['start_time'] = startTime;
      if (endTime != null) data['end_time'] = endTime;

      final response = await _apiClient.patch(
        path: '${ApiEndpoint.timeSlots}/$id',
        data: data,
      );
      if (response.isSuccess()) {
        return DataSuccess<TimeSlot>(
          TimeSlot.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<TimeSlot>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in updateTimeSlot: $e');
      return DataFailed<TimeSlot>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in updateTimeSlot: $e');
      return DataFailed<TimeSlot>(e.toString());
    }
  }

  @override
  Future<DataState<void>> deleteTimeSlot(int id) async {
    try {
      final response = await _apiClient.delete(
        path: '${ApiEndpoint.timeSlots}/$id',
      );
      if (response.isSuccess()) {
        return const DataSuccess<void>(null);
      }
      return DataFailed<void>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in deleteTimeSlot: $e');
      return DataFailed<void>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in deleteTimeSlot: $e');
      return DataFailed<void>(e.toString());
    }
  }
}
