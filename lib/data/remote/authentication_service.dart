import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:flutter_liveness_detection_randomized_plugin/index.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/api_response.dart';
import '../../common/api_client/data_state.dart';
import 'api_endpoint.dart';
import 'authentication/login_request.dart';
import 'authentication/login_response.dart';

abstract class AuthenticationService {
  Future<DataState<LoginResponse>> login(LoginRequest data);
  Future<DataState<String>> logout();
  Future<DataState<UserInfo>> getMe();
}

@LazySingleton(as: AuthenticationService)
class AuthenticationServiceImplement extends AuthenticationService {
  AuthenticationServiceImplement(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DataState<LoginResponse>> login(LoginRequest data) async {
    try {
      final ApiResponse response =
          await _apiClient.post(path: ApiEndpoint.login, data: data.toJson());
      if (response.isSuccess()) {
        return DataSuccess<LoginResponse>(
            LoginResponse.fromJson(response.data as Map<String, dynamic>));
      }
      return DataFailed<LoginResponse>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in login: $e');
      return DataFailed<LoginResponse>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in login: $e');
      return DataFailed<LoginResponse>(e.toString());
    }
  }

  @override
  Future<DataState<String>> logout() async {
    try {
      final ApiResponse response =
          await _apiClient.post(path: ApiEndpoint.logout);
      if (response.isSuccess()) {
        final data = response.data as Map<String, dynamic>?;
        return DataSuccess<String>(data?['message'] ?? 'Logout success');
      }
      return DataFailed<String>(response.error ?? 'Logout failed');
    } on DioError catch (e) {
      await pushLog('Error in logout: $e');
      return DataFailed<String>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in logout: $e');
      return DataFailed<String>(e.toString());
    }
  }

  @override
  Future<DataState<UserInfo>> getMe() async {
    try {
      final ApiResponse response = await _apiClient.get(path: ApiEndpoint.me);
      if (response.isSuccess()) {
        return DataSuccess<UserInfo>(
            UserInfo.fromJson(response.data as Map<String, dynamic>));
      }
      return DataFailed<UserInfo>(response.error ?? 'Failed to get profile');
    } on DioError catch (e) {
      await pushLog('Error in getMe: $e');
      return DataFailed<UserInfo>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getMe: $e');
      return DataFailed<UserInfo>(e.toString());
    }
  }
}
