import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/enums/server_type.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/models/batch_student_response.dart';
import 'package:face_time_keeping/data/models/register_user_request.dart';
import 'package:face_time_keeping/data/models/student_request.dart';
import 'package:face_time_keeping/data/models/upload_response.dart';
import 'package:face_time_keeping/di/injection.dart';

import 'package:face_time_keeping/entities/student.dart';
import 'package:face_time_keeping/entities/face_data.dart';
import 'package:face_time_keeping/entities/person.dart';
import 'package:face_time_keeping/entities/register_student.dart';
import 'package:face_time_keeping/entities/sync_response.dart';
import 'package:flutter/material.dart';

import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/api_response.dart';
import '../../common/api_client/data_state.dart';
import 'api_endpoint.dart';
import 'package:http/http.dart' as http;

abstract class UserService {
  Future<DataState<List<Student>>> getStudents();
  Future<DataState<List<UserInfo>>> getUsersByRole(String role);
  Future<DataState<bool>> syncCheckInOutData({String? url});
  Future<DateTime> fetchWorldTime({String timezone = 'Etc/UTC'});
  Future<DataState<Student>> registerStudent(
      RegisterStudent registerStudent);
  Future<DataState<BatchStudentResponse>> registerStudents(
      CreateStudentBatchRequest request);
  Future<void> testFunction();
  Future<DataState<String>> pushFaceData({String? url});
  Future<DataState<String>> pullFaceData({String? url});
  Future<DataState<String>> syncStudentData({String? url});
  Future<DataState<UploadResponse>> uploadAvatars(List<File> files);
  Future<DataState<RegisterUserResponse>> registerUser(
      RegisterUserRequest request);
}

@LazySingleton(as: UserService)
class UserServiceImplement implements UserService {
  UserServiceImplement(this._apiClient, this._localService);

  final ApiClient _apiClient;
  final LocalService _localService;

  @override
  Future<void> testFunction() async {
    try {
      final response =
          await _apiClient.get(path: "/web/content/411?download=true");
      if (response.isSuccess()) {
        return response.data;
      }
    } catch (e) {
      await pushLog('Error in testFunction: $e');
    }
  }

  @override
  Future<DataState<String>> pullFaceData({String? url}) async {
    try {
      final DateTime? latestTime =
          await _localService.getLatestTimePullFaceData();
      final Map<String, dynamic> queryParameters = {};
      if (latestTime != null) {
        queryParameters['from_date'] =
            latestTime.toIso8601String().split('.').first;
      }
      final response = await getIt<Dio>().request<dynamic>(
          url != null
              ? '$url${ApiEndpoint.pullFaceData}'
              : ApiEndpoint.pullFaceData,
          queryParameters: queryParameters,
          options: Options(
            method: 'GET',
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
          ));
      final data = response.data as List<dynamic>;
      if (data.isNotEmpty) {
        final now = DateTime.now();
        final faceDataList = data.map((e) => FaceData.fromJson(e)).toList();
        await _localService.importFaceData(faceDataList);
        await _localService.saveLatestTimePullFaceData(now);
      }
      return DataSuccess<String>(
          response.statusMessage ?? 'Cập nhật dữ liệu thành công');
    } catch (e) {
      await pushLog('Error in pullFaceData: $e');
      return DataFailed<String>(e.toString());
    }
  }

  @override
  Future<DataState<String>> pushFaceData({String? url}) async {
    try {
      final newPersons = await _localService.getPersonsUnSynced();
      if (newPersons.isEmpty) {
        return const DataSuccess<String>('Không có dữ liệu để đồng bộ');
      }
      final listPushedPersonIds = newPersons.map((e) => e.studentId).toList();
      final file =
          await _localService.exportModelToJsonFile(persons: newPersons);
      final multiPartFile = await MultipartFile.fromFile(file.path,
          filename: file.uri.pathSegments.last);
      final formData = FormData.fromMap({
        'file': multiPartFile,
      });
      final response = await _apiClient.put(
        path: url != null
            ? '$url${ApiEndpoint.pushFaceData}'
            : ApiEndpoint.pushFaceData,
        data: formData,
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      );
      debugPrint('response: ${response.data}');
      if (response.isSuccess()) {
        final listSkippedPersonIds =
            response.data['data']['skipped'] as List<dynamic>? ?? [];
        final listSkippedPersonIdsInt =
            listSkippedPersonIds.map((e) => e as int).toList();
        for (final personId in listPushedPersonIds) {
          if (!listSkippedPersonIdsInt.contains(personId)) {
            await _localService.setPersonSynced(personId);
          }
        }
        return DataSuccess<String>(response.data['message']);
      }
      return DataFailed<String>(response.error);
    } catch (e) {
      await pushLog('Error in pushFaceData: $e');
      return DataFailed<String>(e.toString());
    }
  }

  @override
  Future<DateTime> fetchWorldTime({String timezone = 'Etc/UTC'}) async {
    try {
      final res = await http
          .get(Uri.parse('https://worldtimeapi.org/api/timezone/$timezone'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return DateTime.parse(data['utc_datetime']);
      }
    } catch (e) {
      await pushLog('Error in fetchWorldTime: $e');
    }
    return DateTime.now();
  }

  @override
  Future<DataState<Student>> registerStudent(
      RegisterStudent registerStudent) async {
    try {
      final json = await registerStudent.toJson();
      FormData formData = FormData.fromMap(json);

      final ApiResponse response = await _apiClient.post(
        path: ApiEndpoint.registerStudent,
        data: formData,
      );

      if (response.isSuccess()) {
        final studentData = response.data as Map<String, dynamic>;
        final student = Student.fromJson(studentData['data']);
        return DataSuccess<Student>(student);
      } else {
        return DataFailed<Student>(response.error ?? 'Registration failed');
      }
    } catch (e) {
      await pushLog('Error in registerStudent: $e');
      return DataFailed<Student>(e.toString());
    }
  }

  @override
  Future<DataState<bool>> syncCheckInOutData({String? url}) async {
    try {
      final bulkUsers = await _localService.getBulkUsers();
      if (bulkUsers == null || bulkUsers.isEmpty) {
        return const DataFailed<bool>('Không còn dữ liệu để đồng bộ');
      }
      // Format the payload according to the required structure
      final List<Map<String, dynamic>> bulkUsersPayload =
          bulkUsers.map((bulkUser) {
        final Map<String, dynamic> payload = {
          'io': bulkUser.checkInOuts
              .map((checkInOut) => checkInOut.toSmallJson())
              .toList(),
        };

        // Use pin if available, otherwise use student_id
        if (bulkUser.pin != null && bulkUser.pin!.isNotEmpty) {
          final pinNumber = int.tryParse(bulkUser.pin!);
          payload['pin'] = pinNumber ?? bulkUser.pin;
        } else {
          payload['student_id'] = bulkUser.studentId;
        }

        return payload;
      }).toList();

      final Map<String, dynamic> requestPayload = {
        'bulk_users': bulkUsersPayload,
      };
      ApiResponse response;
      if (url != null) {
        response = await _apiClient.post(
          path: '$url${ApiEndpoint.syncCheckInOutData}',
          data: requestPayload,
        );
      } else {
        response = await _apiClient.post(
          path: ApiEndpoint.syncCheckInOutData,
          data: requestPayload,
        );
      }

      if (response.isSuccess()) {
        debugPrint('Sync completed successfully: ${response.data}');
        final responseData = response.data as Map<String, dynamic>;
        final dataList = responseData['data'] as List<dynamic>;
        final data = dataList.cast<Map<String, dynamic>>();

        for (final item in data) {
          final syncResponse = SyncResponse.fromJson(item);
          if (syncResponse.success) {
            debugPrint('Sync completed successfully: ${syncResponse.message}');
            await _localService.handleSyncResponse(syncResponse);
          } else {
            debugPrint('Sync failed for item: ${syncResponse.message}');
          }
        }
        return const DataSuccess<bool>(true);
      } else {
        debugPrint('Sync failed: ${response.error}');
        return DataFailed<bool>(response.error);
      }
    } on DioError catch (e) {
      await pushLog('Error in syncCheckInOutData: $e');
      debugPrint('Dio error during sync: ${e.message}');
      return DataFailed<bool>(e.message);
    } catch (e) {
      await pushLog('Error in syncCheckInOutData: $e');
      debugPrint('General error during sync: $e');
      return DataFailed<bool>(e.toString());
    }
  }

  @override
  Future<DataState<List<Student>>> getStudents() async {
    try {
      final ApiResponse response =
          await _apiClient.get(path: ApiEndpoint.students);
      if (response.isSuccess()) {
        final json = response.data;
        debugPrint('json: $json');
        final realData = json['data'];
        final studentsData = realData['students'] as List<dynamic>;
        final students =
            studentsData.map((e) => Student.fromJson(e)).toList();
        return DataSuccess<List<Student>>(students);
      }
      return DataFailed<List<Student>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getStudents: $e');
      return DataFailed<List<Student>>(e.message);
    } catch (e, stackTrace) {
      await pushLog('Error in getStudents: $e');
      debugPrint('General error in getStudents: $e\n$stackTrace');
      return DataFailed<List<Student>>(e.toString());
    }
  }

  @override
  Future<DataState<List<UserInfo>>> getUsersByRole(String role) async {
    try {
      final ApiResponse response = await _apiClient.get(
        path: '${ApiEndpoint.getUsersByRole}?role=$role',
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>;
        final users = items
            .map((e) => UserInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<UserInfo>>(users);
      }
      return DataFailed<List<UserInfo>>(response.error);
    } catch (e) {
      await pushLog('Error in getUsersByRole: $e');
      return DataFailed<List<UserInfo>>(e.toString());
    }
  }

  @override
  Future<DataState<BatchStudentResponse>> registerStudents(
      CreateStudentBatchRequest request) async {
    try {
      final ApiResponse response = await _apiClient.post(
        path: ApiEndpoint.registerStudentBatch,
        data: request.toJson(),
      );

      if (response.isSuccess()) {
        final studentData = response.data as Map<String, dynamic>;
        final student = BatchStudentResponse.fromJson(studentData['data']);
        return DataSuccess<BatchStudentResponse>(student);
      } else {
        return DataFailed<BatchStudentResponse>(
            response.error ?? 'Registration failed');
      }
    } catch (e) {
      await pushLog('Error in registerStudents: $e');
      return DataFailed<BatchStudentResponse>(e.toString());
    }
  }

  @override
  Future<DataState<String>> syncStudentData({String? url}) async {
    try {
      // Get unsynced local students
      final unsyncedStudents = await _localService.getUnsyncedLocalStudents();

      if (unsyncedStudents.isEmpty) {
        // No local students to sync, just pull from server
        await _syncServerToLocalStudents();
        return const DataSuccess<String>('Đồng bộ học sinh thành công');
      }

      final unsyncStudentsWithoutAvatar = unsyncedStudents
          .where((person) => person.avatar == null || person.avatar!.isEmpty)
          .toList();

      final unsyncStudentsHasAvatar = unsyncedStudents
          .where((person) => person.avatar != null && person.avatar!.isNotEmpty)
          .toList();
      if (unsyncStudentsWithoutAvatar.isNotEmpty) {
        await _createStudent(unsyncStudentsWithoutAvatar);
      }
      if (unsyncStudentsHasAvatar.isNotEmpty) {
        await _createStudent(unsyncStudentsHasAvatar);
      }

      // Fetch all students from server and update local DB
      await _syncServerToLocalStudents();
      return const DataSuccess<String>('Đồng bộ học sinh thành công');
    } catch (e) {
      await pushLog('Error in syncStudentData: $e');
      return DataFailed<String>('Lỗi đồng bộ học sinh: $e');
    }
  }

  Future<void> _createStudent(List<Person> persons) async {
    final files = persons
        .map((person) => person.avatar)
        .nonNulls
        .map((path) => File(path))
        .toList();
    List<StudentRequest> requests = [];
    DataState<UploadResponse>? result;
    String? uploadId;
    if (files.isNotEmpty) {
      result = await uploadAvatars(files);
      uploadId = result.data?.uploadId;
      for (var i = 0; i < (result.data?.files.length ?? 0); i++) {
        requests.add(StudentRequest(
          name: persons[i].name ?? 'Unknown',
          pin: persons[i].pin ?? '',
          jobTitle: persons[i].jobTitle?.toString() ?? '',
          avatar: result.data?.files[i].tempId,
        ));
      }
    } else {
      requests = persons.map((person) {
        return StudentRequest(
          name: person.name ?? 'Unknown',
          pin: person.pin ?? '',
          jobTitle: person.jobTitle?.toString() ?? '',
        );
      }).toList();
    }

    final request =
        CreateStudentBatchRequest(uploadId: uploadId, students: requests);
    final response = await registerStudents(request);
    if (response.isSuccess) {
      // Mark all synced students as synced in local DB
      if ((response.data?.createdStudents ?? []).isNotEmpty) {
        final serverType = await _localService.getServerType();
        final serverName = serverType?.label ?? 'Server';

        await _localService.syncStudentsFromServer(
            response.data?.createdStudents ?? [], serverName);
      }
    }
  }

  Future<void> _syncServerToLocalStudents() async {
    final serverType = await _localService.getServerType();
    final serverName = serverType?.label ?? 'Server';
    final studentsResult = await getStudents();
    if (studentsResult.isSuccess && studentsResult.data != null) {
      await _localService.syncStudentsFromServer(
        studentsResult.data!,
        serverName,
      );
    }
  }

  @override
  Future<DataState<UploadResponse>> uploadAvatars(List<File> files) async {
    try {
      // Create FormData with multiple files
      FormData formData = FormData();

      for (var file in files) {
        String fileName = file.path.split('/').last;
        formData.files.add(
          MapEntry(
            'files',
            await MultipartFile.fromFile(
              file.path,
              filename: fileName,
            ),
          ),
        );
      }

      final ApiResponse response = await _apiClient.post(
        path: ApiEndpoint.uploadStudentAvatar,
        data: formData,
      );

      if (response.isSuccess()) {
        final uploadData = response.data as Map<String, dynamic>;
        final uploadResponse = UploadResponse.fromJson(uploadData['data']);
        return DataSuccess<UploadResponse>(uploadResponse);
      } else {
        return DataFailed<UploadResponse>(response.error ?? 'Upload failed');
      }
    } catch (e) {
      await pushLog('Error in uploadAvatars: $e');
      return DataFailed<UploadResponse>(e.toString());
    }
  }

  @override
  Future<DataState<RegisterUserResponse>> registerUser(
      RegisterUserRequest request) async {
    try {
      final ApiResponse response = await _apiClient.post(
        path: ApiEndpoint.registerUser,
        data: request.toJson(),
      );

      if (response.isSuccess()) {
        final responseData = response.data as Map<String, dynamic>;
        final userData = RegisterUserResponse.fromJson(responseData);
        return DataSuccess<RegisterUserResponse>(userData);
      } else {
        return DataFailed<RegisterUserResponse>(
            response.error ?? 'Registration failed');
      }
    } catch (e) {
      await pushLog('Error in registerUser: $e');
      return DataFailed<RegisterUserResponse>(e.toString());
    }
  }
}
