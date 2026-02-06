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
  Future<DataState<List<String>>> getDatabaseList();
  Future<DataState<int>> authenticateDatabase(String userName,String password,String database);//this method will contain the session id in cookie
}

@LazySingleton(as: AuthenticationService)
class AuthenticationServiceImplement extends AuthenticationService {
  AuthenticationServiceImplement(this._apiClient);

  final ApiClient _apiClient;

@override
Future<DataState<List<String>>> getDatabaseList() async {
  try {
    final ApiResponse response = await _apiClient.post(path: ApiEndpoint.databaseList,data:{
	"jsonrpc": "2.0",
	"params": {
	},
	"id": 1
}
);
debugPrint(response.data.toString());
if (response.isSuccess()) {
  final result = response.data['result'];
  if (result is List) {
    final dbList = result.map((e) => e.toString()).toList();
    return DataSuccess<List<String>>(dbList);
  }
}
return DataFailed<List<String>>(response.error);
  }
  catch(e){
    await pushLog('Error in getDatabaseList: $e');
    return DataFailed<List<String>>(e.toString());
  }
}
int extractUserId(Map<String, dynamic> decoded) {
  return decoded['result']['user_settings']['user_id']['id'] as int;
}

@override
Future<DataState<int>> authenticateDatabase(String userName,String password,String database) async {
  try {
    final ApiResponse response = await _apiClient.post(path: ApiEndpoint.authDatabase,data:{
	"jsonrpc": "2.0",
	"params": {
		"db": database,
		"login": userName,
		"password": password
	}
}

);
if(response.isSuccess()){
  final userId = extractUserId(response.data);
  return DataSuccess<int>(userId);
}
return DataFailed<int>(response.error);
  }
  catch(e){
    await pushLog('Error in authenticateDatabase: $e');
    return DataFailed<int>(e.toString());
  }
}
  @override
  Future<DataState<LoginResponse>> login(LoginRequest data) async {
    try {
      
      final ApiResponse response =
          await _apiClient.get(path: ApiEndpoint.login, headers: data.toJson());
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
}
