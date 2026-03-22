import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/api_response.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/schedule.dart';
import '../../entities/time_slot.dart';
import 'api_endpoint.dart';

abstract class ScheduleService {
  Future<DataState<List<Schedule>>> getSchedules({
    String? courseId,
    int? dayOfWeek,
    int? limit,
    int? offset,
  });
  Future<DataState<Schedule>> createSchedule({
    required String courseId,
    required int dayOfWeek,
    required int timeSlotId,
  });
  Future<DataState<Schedule>> updateSchedule({
    required String id,
    int? dayOfWeek,
    int? timeSlotId,
  });
  Future<DataState<void>> deleteSchedule(String id);
  Future<DataState<List<TimeSlot>>> getTimeSlots({int? limit, int? offset});
}

@LazySingleton(as: ScheduleService)
class ScheduleServiceImplement implements ScheduleService {
  ScheduleServiceImplement(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DataState<List<Schedule>>> getSchedules({
    String? courseId,
    int? dayOfWeek,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (courseId != null) queryParams['course_id'] = courseId;
      if (dayOfWeek != null) queryParams['day_of_week'] = dayOfWeek;
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['skip'] = offset;

      final ApiResponse response = await _apiClient.get(
        path: ApiEndpoint.schedules,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>;
        final schedules = items
            .map((e) => Schedule.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<Schedule>>(schedules);
      }
      return DataFailed<List<Schedule>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getSchedules: $e');
      return DataFailed<List<Schedule>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getSchedules: $e');
      return DataFailed<List<Schedule>>(e.toString());
    }
  }

  @override
  Future<DataState<Schedule>> createSchedule({
    required String courseId,
    required int dayOfWeek,
    required int timeSlotId,
  }) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.schedules,
        data: {
          'course_id': courseId,
          'day_of_week': dayOfWeek,
          'time_slot_id': timeSlotId,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<Schedule>(
          Schedule.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Schedule>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in createSchedule: $e');
      return DataFailed<Schedule>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in createSchedule: $e');
      return DataFailed<Schedule>(e.toString());
    }
  }

  @override
  Future<DataState<Schedule>> updateSchedule({
    required String id,
    int? dayOfWeek,
    int? timeSlotId,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (dayOfWeek != null) data['day_of_week'] = dayOfWeek;
      if (timeSlotId != null) data['time_slot_id'] = timeSlotId;

      final response = await _apiClient.put(
        path: '${ApiEndpoint.schedules}/$id',
        data: data,
      );
      if (response.isSuccess()) {
        return DataSuccess<Schedule>(
          Schedule.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Schedule>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in updateSchedule: $e');
      return DataFailed<Schedule>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in updateSchedule: $e');
      return DataFailed<Schedule>(e.toString());
    }
  }

  @override
  Future<DataState<void>> deleteSchedule(String id) async {
    try {
      final response =
          await _apiClient.delete(path: '${ApiEndpoint.schedules}/$id');
      if (response.isSuccess()) {
        return const DataSuccess<void>(null);
      }
      return DataFailed<void>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in deleteSchedule: $e');
      return DataFailed<void>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in deleteSchedule: $e');
      return DataFailed<void>(e.toString());
    }
  }

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
        final items = json['items'] as List<dynamic>;
        final timeSlots = items
            .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<TimeSlot>>(timeSlots);
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
}
