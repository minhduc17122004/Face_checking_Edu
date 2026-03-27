import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:collection/collection.dart';
import 'package:face_native/face_native.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/common/utils/sync_jobs_util.dart';
import 'package:face_time_keeping/configs/build_config.dart';
import 'package:face_time_keeping/data/local/hive_service.dart';
import 'package:face_native/models/face_image_record.dart';
import 'package:face_time_keeping/entities/bulk_user.dart';
import 'package:face_time_keeping/entities/check_in_out.dart';
import 'package:face_time_keeping/entities/check_out.dart';
import 'package:face_time_keeping/entities/student.dart';
import 'package:face_time_keeping/entities/face_data.dart';
import 'package:face_time_keeping/entities/pending_edu_check_in.dart';
import 'package:face_time_keeping/entities/person.dart';
import 'package:face_time_keeping/entities/sync_face_schedule.dart';
import 'package:face_time_keeping/entities/sync_response.dart';
import 'package:face_time_keeping/entities/sync_schedule.dart';
import 'package:face_time_keeping/entities/tenant.dart';
import 'package:face_time_keeping/utils/csv_util.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart'
    hide Student;
import 'package:face_time_keeping/common/event/event_bus_mixin.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:face_time_keeping/common/enums/server_type.dart';

import '../../common/api_client/api_client.dart';
import '../../di/injection.dart';
import 'keychain/shared_prefs.dart';
import 'keychain/shared_prefs_key.dart';

abstract class LocalService {
  void saveLoginId(String? loginId);
  String getLoginId();
  void saveUserEmail(String? email);
  String getUserEmail();
  void saveUserFullName(String? fullName);
  String getUserFullName();
  String getAuthToken();
  void saveAuthToken(String? token);
  String? getRefreshToken();
  void saveRefreshToken(String? token);
  void saveServerUrl(String? domain);
  String getServerUrl();
  List<String> getRecentDomains();
  void saveRecentDomain(String? domain);
  Future<void> clearServerRelatedData();
  Future<void> initApp();
  Future<Map<String, dynamic>> checkIn(CheckInOut checkIn, {DateTime? sessionStartTime, String? sessionId});
  Future<Map<String, dynamic>> checkOut(CheckOut checkOut, Position location);
  Future<void> saveShiftTimes({
    required TimeOfDay morningStart,
    required TimeOfDay morningEnd,
    required TimeOfDay afternoonStart,
    required TimeOfDay afternoonEnd,
    required TimeOfDay nightStart,
    required TimeOfDay nightEnd,
  });
  Future<Map<String, TimeOfDay>> getShiftTimes();
  Future<bool> isRegistered(int studentId);
  Future<List<CheckInOut>> getCheckInOutByDate(DateTime date);
  Future<List<BulkUser>?> getBulkUsers();
  Future<void> handleSyncResponse(SyncResponse syncResponse);
  Future<String> getLicenseKey();
  Future<void> saveLicenseKey(String licenseKey);
  Future<String?> getPinApp();
  Future<void> savePinApp(String pinApp);
  Future<List<SyncSchedule>> getSyncSchedules();
  Future<void> saveSyncSchedules(List<SyncSchedule> syncSchedules);
  Future<bool> scheduleSyncData(SyncSchedule syncSchedule);
  Future<void> cancelSyncData(SyncSchedule syncSchedule);
  Future<void> cancelAllSyncData();
  Future<void> clearSyncSchedules();
  Future<File> exportCheckInOutToCsv(DateTime? date);
  Future<File> exportCheckInOutToExcel(DateTime? date);
  Future<bool> shareModelJsonFile();
  Future<List<FaceImageRecord>> importFromJsonFile(String path);
  Future<String> getDatabaseName();
  Future<void> saveDatabaseName(String dbName);
  Future<int?> getUserId();
  Future<void> saveUserId(int userId);
  Future<int> getTenantIdOrSaveTenant(String url, String dbName);
  Future<File> exportModelToJsonFile({List<Person>? persons});
  Future<void> saveTenantId(int tenantId);
  Future<int> getTenantId();
  Future<List<Person>> getPersonsUnSynced();
  Future<DateTime?> getLatestTimePullFaceData();
  Future<void> saveLatestTimePullFaceData(DateTime latestTime);
  Future<void> importFaceData(List<FaceData> faceDataList);
  Future<void> resetBothLatestTime();
  Future<void> setPersonSynced(int personId);
  Future<SyncFaceSchedule?> getSyncFaceSchedule();
  Future<void> saveSyncFaceSchedule(SyncFaceSchedule syncFaceSchedule);
  Future<void> clearSyncFaceSchedule();
  Future<void> refreshCheckInOutBox();
  Future<bool> getIsInitializedDefaultData();
  Future<void> saveIsInitializedDefaultData(bool isInitializedDefaultData);
  Future<void> initDefaultData();
  Future<ServerType?> getServerType();
  Future<ServerType?> getTempServerType();
  Future<void> saveServerType(ServerType serverType);
  Future<void> saveTempServerType(ServerType serverType);
  Future<bool> hasUnsyncedLocalStudents();
  Future<List<Person>> getUnsyncedLocalStudents();
  Future<void> syncStudentsFromServer(
      List<Student> students, String serverName);
  Future<void> cloneDataFromPreviousTenant(int oldTenantId, int newTenantId);
  Future<void> clearAllData();
  void saveAvatarPath(String? path);
  String getAvatarPath();
  void saveUserRole(String? role);
  String getUserRole();
  Future<String> getDeviceCode();
  Future<void> saveDeviceCode(String code);
  Future<void> saveActiveRoomId(String roomId);
  Future<String?> getActiveRoomId();
  Future<void> saveActiveRoomName(String roomName);
  Future<String?> getActiveRoomName();

  // --- EDU Pending Check-In (offline queue) ---
  Future<void> savePendingEduCheckIn(PendingEduCheckIn item);
  Future<List<PendingEduCheckIn>> getPendingEduCheckIns();
  Future<void> markEduCheckInSynced(String localId);
  Future<void> incrementEduRetryCount(String localId);
  Future<void> clearSyncedEduCheckIns();
  Future<void> clearAllEduCheckIns();
}

@LazySingleton(as: LocalService)
class LocalServiceImplement with EventBusMixin implements LocalService {
  LocalServiceImplement(this._sharedPreferences, this._apiClient,
      this._hiveService, this._csvUtil) {
    _faceNative = FaceNative();
  }

  final SharedPrefs _sharedPreferences;
  final HiveService _hiveService;
  final ApiClient _apiClient;
  //{"licenseKey":"paraceltech","owner":"Paracel","issuedDate":"2025-08-29T10:09:48","licenseExpiredDate":"2026-05-20T23:59:59"}
  static const defaultLicenseKey =
      "WHF4enplZXB1STZpV0dQVFBlRWpvamFtUVRVTUEwOHhIY1B4Rm5FYUJBVkpYM2trVG43bmdweHdOazFKdVRkL0Z1L3NiNXRqYzhiaGxRbWRMUXFaOGYwazJ5dHZnSm05ZFE4QkNJSjVWY212azlRRFNjMXNheDJHbjUzL3Q0MHRiajZueXlPR1Jua0s1WjlvVkFwY096bUlBeXBET0JSa0J4MEtKTUNNUlJwZXdOMmlVWU4rUGo2aUVNc3pmRTBGNjFVQWJ5NUpCbFdzWi92d1p5UVVCMitFZ0RmMnRIRWVpdHpSWHVpQW12SXVURTVORTlyMDRzY2plQXorWVQyb0tqaDBiRlo4L21ETXBmVy9PeG9sSWpXV01zZzVYQUNBTXdTRG4vSWlrOFJWQ2tMY0R4T0Y5NXJlS08zd2pmR1Rwb05sZEdwcFo2UHo1Ty9kWFFKODRRPT06dWVJMGtjZVZCYmlXOW1rcU1KMVRqNTIvUDNNWHA3MmttcXdOUEVkVW5COEVzdHhlQVR0Z3FEaU9EaXo3R3lzdnNXWWMyNS9IQ2YrVnptL0xJZUdYNEsyU25MczlOcHZXRER2QWJWbk5aNVYvZjBwaDUwSG5qWkpFc2VBREY4dVFxdDZ5NzhnUTVHTHp3QkYrdS9XUU9OSmRnRHh6aEVFV2t0cmp0QkhWVmZRPQ==";

  @override
  Future<ServerType?> getServerType() async {
    try {
      final s = _sharedPreferences.get<String>(SharedPrefsKey.serverType);
      return serverTypeFromString(s);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ServerType?> getTempServerType() async {
    try {
      final s = _sharedPreferences.get<String>(SharedPrefsKey.tempServerType);
      return serverTypeFromString(s);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveServerType(ServerType serverType) async {
    try {
      await _sharedPreferences.put<String>(
          SharedPrefsKey.serverType, serverType.value);
    } catch (e) {
      // ignore
    }
  }

  @override
  Future<void> saveTempServerType(ServerType serverType) async {
    try {
      await _sharedPreferences.put<String>(
          SharedPrefsKey.tempServerType, serverType.value);
    } catch (e) {
      // ignore
    }
  }

  final CsvUtil _csvUtil;
  late final FaceNative _faceNative;
  Future<String> _formatWithTenantId(String key) async {
    final tenantId = await getTenantId();
    return '$key-$tenantId';
  }

  @override
  Future<void> refreshCheckInOutBox() async {
    await _hiveService.refreshCheckInOutBox();
  }

  @override
  Future<SyncFaceSchedule?> getSyncFaceSchedule() async {
    try {
      final syncFaceScheduleJson =
          _sharedPreferences.get<String>(SharedPrefsKey.syncFaceSchedule);
      return syncFaceScheduleJson == null
          ? null
          : SyncFaceSchedule.fromJson(jsonDecode(syncFaceScheduleJson));
    } catch (e) {
      await pushLog('Error in getSyncFaceSchedule: $e');
      rethrow;
    }
  }

  @override
  Future<void> initDefaultData() async {
    try {
      final selectedServerType = (await getServerType()) ?? ServerType.none;
      final isInitializedDefaultData = await getIsInitializedDefaultData();
      if (!isInitializedDefaultData && selectedServerType != ServerType.none) {
        final syncSchedule = SyncSchedule(
            time: '08:00', repeatIntervalHours: 0, repeatIntervalMinutes: 30);
        await SyncJobsUtil.scheduleSyncData(syncSchedule);
        await saveSyncSchedules([syncSchedule]);
        final syncFaceSchedule =
            SyncFaceSchedule(repeatIntervalHours: 0, repeatIntervalMinutes: 15);
        await SyncJobsUtil.scheduleSyncFaceData(syncFaceSchedule);
        await saveSyncFaceSchedule(syncFaceSchedule);
        await saveIsInitializedDefaultData(true);
      }
    } catch (e) {
      await pushLog('Error in initDefaultData: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveSyncFaceSchedule(SyncFaceSchedule syncFaceSchedule) async {
    try {
      final syncFaceScheduleJson = jsonEncode(syncFaceSchedule.toJson());
      final oldSyncFaceSchedule = await getSyncFaceSchedule();

      await _sharedPreferences.put(
          SharedPrefsKey.syncFaceSchedule, syncFaceScheduleJson);
      await SyncJobsUtil.scheduleSyncFaceData(syncFaceSchedule);
      if (oldSyncFaceSchedule != null) {
        await SyncJobsUtil.cancelSyncFaceData(oldSyncFaceSchedule);
      }
    } catch (e) {
      await pushLog('Error in saveSyncFaceSchedule: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearSyncFaceSchedule() async {
    try {
      final oldSyncFaceSchedule = await getSyncFaceSchedule();
      if (oldSyncFaceSchedule != null) {
        await SyncJobsUtil.cancelSyncFaceData(oldSyncFaceSchedule);
      }
      await _sharedPreferences.clearKey(SharedPrefsKey.syncFaceSchedule);
    } catch (e) {
      await pushLog('Error in clearSyncFaceSchedule: $e');
      rethrow;
    }
  }

  @override
  Future<void> setPersonSynced(int personId) async {
    try {
      final person = await _hiveService.getPerson(personId);
      if (person != null) {
        await _hiveService.updatePerson(person.copyWith(isSynced: true));
      }
    } catch (e) {
      await pushLog('Error in setPersonSynced: $e');
      rethrow;
    }
  }

  @override
  Future<void> importFaceData(List<FaceData> faceDataList) async {
    try {
      // miss new person
      final persons = await _hiveService.getAllPersons();
      for (final faceData in faceDataList) {
        final person =
            persons.firstWhereOrNull((e) => e.studentId == faceData.empId);
        if ((person != null &&
                person.updatedTime.isBefore(faceData.updatedTime)) ||
            person == null) {
          if (faceData.listFaceEmbedding.isNotEmpty) {
            await _faceNative.removeImages(faceData.empId);
          }
          final listFaceImageRecord = <FaceImageRecord>[];
          for (final embedding in faceData.listFaceEmbedding) {
            if (embedding.isEmpty) continue;
            final faceImageRecord = FaceImageRecord(
                personName: faceData.personName!,
                empId: faceData.empId,
                faceEmbedding: embedding);
            listFaceImageRecord.add(faceImageRecord);
          }
          if (listFaceImageRecord.isNotEmpty) {
            await _faceNative.addAllRecords(listFaceImageRecord);
            final newPerson = (person == null)
                ? Person(
                    studentId: faceData.empId,
                    updatedTime: faceData.updatedTime,
                    name: faceData.personName ?? 'Unknown',
                  )
                : person.copyWith(updatedTime: faceData.updatedTime);
            await _hiveService.updatePerson(newPerson);
          }
        }
      }
    } catch (e) {
      await pushLog('Error in importFaceData: $e');
      rethrow;
    }
  }

  @override
  Future<DateTime?> getLatestTimePullFaceData() async {
    try {
      final key =
          await _formatWithTenantId(SharedPrefsKey.latestTimePullFaceData);
      final latestTime = _sharedPreferences.get(key);
      if (latestTime == null) return null;
      return DateTime.parse(latestTime);
    } catch (e) {
      await pushLog('Error in getLatestTimePullFaceData: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveLatestTimePullFaceData(DateTime latestTime) async {
    final key =
        await _formatWithTenantId(SharedPrefsKey.latestTimePullFaceData);
    await _sharedPreferences.put(
        key, latestTime.toIso8601String().split('.').first);
  }

  @override
  Future<List<Person>> getPersonsUnSynced() async {
    try {
      final persons = await _hiveService.getAllPersons();
      final personsUnSynced = persons.where((e) => !e.isSynced).toList();
      return personsUnSynced;
    } catch (e) {
      await pushLog('Error in getPersonsUnSynced: $e');
      rethrow;
    }
  }

  @override
  Future<int> getTenantId() async {
    try {
      final tenantId = _sharedPreferences.get(SharedPrefsKey.tenantId);
      if (tenantId == null) {
        throw Exception('Tenant ID not found');
      }
      return tenantId;
    } catch (e) {
      await pushLog('Error in getTenantId: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveTenantId(int tenantId) async {
    await _sharedPreferences.put(SharedPrefsKey.tenantId, tenantId);
  }

  @override
  Future<int> getTenantIdOrSaveTenant(String url, String dbName) async {
    try {
      final tenantId = await _hiveService.getTenantId(url, dbName);
      if (tenantId == null) {
        final tenant = Tenant(url: url, databaseName: dbName);
        return await _hiveService.addTenant(tenant);
      }
      return tenantId;
    } catch (e) {
      await pushLog('Error in getTenantIdOrSaveTenant: $e');
      rethrow;
    }
  }

  @override
  Future<String> getDatabaseName() async {
    return _sharedPreferences.get(SharedPrefsKey.dbName) ?? '';
  }

  @override
  Future<void> saveDatabaseName(String dbName) async {
    await _sharedPreferences.put(SharedPrefsKey.dbName, dbName);
  }

  @override
  Future<File> exportModelToJsonFile({List<Person>? persons}) async {
    try {
      late final records;
      if (persons == null || persons.isEmpty) {
        records = await _faceNative.getAllImages();
      } else {
        final personIds = persons.map((e) => e.studentId).toList();
        records = await _faceNative.getFaceImageRecordByListEmpId(personIds);
      }
      final map = <int, List<List<double>>>{};
      for (final record in records) {
        map.putIfAbsent(record.empId, () => []);
        map[record.empId]!.add(record.faceEmbedding);
      }
      final mapUpdatedTime = <int, DateTime>{};
      for (final person in persons ?? []) {
        mapUpdatedTime[person.studentId] = person.updatedTime;
      }
      final faceDataList = map.entries
          .map((e) => FaceData(
              empId: e.key,
              updatedTime: mapUpdatedTime[e.key] ?? DateTime.now(),
              listFaceEmbedding: e.value))
          .toList();
      final jsonList = faceDataList.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      // Write to a temporary file and invoke the share sheet
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final safeTimestamp = now.toIso8601String().replaceAll(':', '-');
      final nameFile = 'face_data_$safeTimestamp.json';
      final file = File('${tempDir.path}/$nameFile');
      await file.writeAsString(jsonString);
      return file;
    } catch (e, stack) {
      await pushLog('Error exporting to JSON file: $e\n$stack');
      log('Error exporting to JSON file: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<bool> shareModelJsonFile() async {
    try {
      final file = await exportModelToJsonFile();

      final shareResult = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              'Dữ liệu khuôn mặt - ${DateTime.now().toIso8601String().split('.').first}',
          subject: 'Dữ liệu khuôn mặt',
        ),
      );
      return shareResult.status == ShareResultStatus.success;
    } catch (e, stack) {
      await pushLog('Error exporting to JSON file: $e\n$stack');
      log('Error exporting to JSON file: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<List<FaceImageRecord>> importFromJsonFile(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        throw Exception('File not found');
      }
      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final list = jsonList.map((e) => FaceImageRecord.fromMap(e)).toList();
      await _faceNative.addAllRecords(list);
      return list;
    } catch (e, stack) {
      log('Error importing from JSON file: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<File> exportCheckInOutToCsv(DateTime? date) async {
    try {
      final checkInOuts = await _hiveService.getCheckInOutsOnOrAfter(date);
      return _csvUtil.exportCheckInOutToCsv(checkInOuts);
    } catch (e) {
      await pushLog('Error in exportCheckInOutToCsv: $e');
      rethrow;
    }
  }

  @override
  Future<File> exportCheckInOutToExcel(DateTime? date) async {
    try {
      final checkInOuts = await _hiveService.getCheckInOutsOnOrAfter(date);
      return await _csvUtil.exportCheckInOutToExcel(checkInOuts);
    } catch (e, s) {
      await pushLog('Error in exportCheckInOutToExcel: $e\n$s');
      rethrow;
    }
  }

  @override
  Future<void> cancelSyncData(SyncSchedule syncSchedule) async {
    try {
      await SyncJobsUtil.cancelSyncData(syncSchedule);
    } catch (e) {
      await pushLog('Error canceling sync data: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelAllSyncData() async {
    try {
      await SyncJobsUtil.cancelAllSyncData();
    } catch (e) {
      await pushLog('Error canceling all sync data: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearSyncSchedules() async {
    try {
      await _sharedPreferences.clearKey(SharedPrefsKey.syncSchedules);
    } catch (e) {
      await pushLog('Error clearing sync schedules: $e');
      rethrow;
    }
  }

  @override
  Future<bool> scheduleSyncData(SyncSchedule syncSchedule) async {
    try {
      await SyncJobsUtil.scheduleSyncData(syncSchedule);
      return true;
    } catch (e) {
      await pushLog('Error scheduling sync data: $e');
      log('Error scheduling sync data: $e');
      return false;
    }
  }

  @override
  Future<List<SyncSchedule>> getSyncSchedules() async {
    try {
      final syncSchedulesJson =
          _sharedPreferences.get<String>(SharedPrefsKey.syncSchedules);
      if (syncSchedulesJson == null || syncSchedulesJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(syncSchedulesJson);
      return decoded
          .map((e) => SyncSchedule.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      await pushLog('Error getting sync schedules: $e');
      log('Error getting sync schedules: $e');
      return [];
    }
  }

  @override
  Future<void> saveSyncSchedules(List<SyncSchedule> syncSchedules) async {
    try {
      final syncSchedulesJson =
          jsonEncode(syncSchedules.map((e) => e.toJson()).toList());
      await _sharedPreferences.put<String>(
          SharedPrefsKey.syncSchedules, syncSchedulesJson);
    } catch (e) {
      await pushLog('Error saving sync schedules: $e');
      log('Error saving sync schedules: $e');
      rethrow;
    }
  }

  @override
  Future<void> handleSyncResponse(SyncResponse syncResponse) async {
    try {
      for (final iOResult in syncResponse.iOResults) {
        if (iOResult.success) {
          await _hiveService.updateCheckInOutFlag(iOResult.ioId, true);
        }
      }
    } catch (e) {
      await pushLog('Error in handleSyncResponse: $e');
      rethrow;
    }
  }

  @override
  Future<String?> getPinApp() async {
    try {
      return _sharedPreferences.get(SharedPrefsKey.pinApp);
    } catch (e) {
      await pushLog('Error in getPinApp: $e');
      rethrow;
    }
  }

  @override
  Future<void> savePinApp(String pinApp) async {
    try {
      await _sharedPreferences.put(SharedPrefsKey.pinApp, pinApp);
    } catch (e) {
      await pushLog('Error in savePinApp: $e');
      rethrow;
    }
  }

  @override
  Future<List<BulkUser>?> getBulkUsers() async {
    try {
      final unSyncedCheckInOuts = await _hiveService.getUnSyncedCheckInOuts();
      final Map<String, List<CheckInOut>> bulkUsers = {};
      for (final checkInOut in unSyncedCheckInOuts) {
        bulkUsers.putIfAbsent(checkInOut.studentId.toString(), () => []);
        bulkUsers[checkInOut.studentId.toString()]!.add(checkInOut);
      }
      return bulkUsers.values
          .map((e) => BulkUser(
              studentId: e.first.studentId, pin: e.first.pin, checkInOuts: e))
          .toList();
    } catch (e, stackTrace) {
      await pushLog('Error in getBulkUsers: $e\n$stackTrace');
      log(
        'Error in getBulkUsers: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'LocalServiceImplement',
      );
    }
    return null;
  }

  @override
  Future<void> initApp() async {
    try {
      final domain = getServerUrl();
      if (domain.isNotEmpty) {
        _apiClient.updateConfigBaseUrl(domain);
      }
      final licenseKey = _sharedPreferences.get(SharedPrefsKey.licenseKey);
      if (licenseKey == null) {
        _sharedPreferences.put(SharedPrefsKey.licenseKey, defaultLicenseKey);
      }
    } catch (e) {
      await pushLog('Error in initApp: $e');
      rethrow;
    }
  }

  @override
  Future<bool> getIsInitializedDefaultData() async {
    return _sharedPreferences.get(SharedPrefsKey.isInitializedDefaultData) ??
        false;
  }

  @override
  Future<void> saveIsInitializedDefaultData(
      bool isInitializedDefaultData) async {
    await _sharedPreferences.put(
        SharedPrefsKey.isInitializedDefaultData, isInitializedDefaultData);
  }

  bool isToday(DateTime date) {
    final today = DateTime.now();
    return date.day == today.day &&
        date.month == today.month &&
        date.year == today.year;
  }

  @override
  Future<List<CheckInOut>> getCheckInOutByDate(DateTime date) async {
    try {
      final checkInOuts = await _hiveService.getAllCheckInOuts();
      return checkInOuts
          .where((checkInOut) =>
              checkInOut.time.day == date.day &&
              checkInOut.time.month == date.month &&
              checkInOut.time.year == date.year)
          .toList();
    } catch (e, stackTrace) {
      await pushLog('Error in getCheckInOutByDate: $e\n$stackTrace');
      log(
        'Error in getCheckInOutByDate: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'LocalServiceImplement',
      );
      return [];
    }
  }

  // Helper method to parse time string to TimeOfDay
  TimeOfDay timeOfDayfromString(String timeString) {
    try {
      if (timeString.isEmpty) {
        return const TimeOfDay(hour: 0, minute: 0);
      }

      final parts = timeString.split(':');
      if (parts.length != 2) {
        return const TimeOfDay(hour: 0, minute: 0);
      }

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      // Validate hour and minute ranges
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return const TimeOfDay(hour: 0, minute: 0);
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      pushLog('Error parsing time string "$timeString": $e');
      log('Error parsing time string "$timeString": $e');
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  String timeOfDayToString(TimeOfDay timeOfDayStart, TimeOfDay timeOfDayEnd) {
    return '${timeOfDayStart.hour}:${timeOfDayStart.minute.toString().padLeft(2, '0')}-${timeOfDayEnd.hour}:${timeOfDayEnd.minute.toString().padLeft(2, '0')}';
  }

  @override
  Future<Map<String, TimeOfDay>> getShiftTimes() async {
    try {
      final morningTime = _sharedPreferences.get(SharedPrefsKey.morningTime) ??
          timeOfDayToString(const TimeOfDay(hour: 8, minute: 0),
              const TimeOfDay(hour: 12, minute: 0));
      final afternoonTime =
          _sharedPreferences.get(SharedPrefsKey.afternoonTime) ??
              timeOfDayToString(const TimeOfDay(hour: 13, minute: 0),
                  const TimeOfDay(hour: 17, minute: 0));
      final nightTime = _sharedPreferences.get(SharedPrefsKey.nightTime) ??
          timeOfDayToString(const TimeOfDay(hour: 18, minute: 0),
              const TimeOfDay(hour: 22, minute: 0));
      return {
        'morningStart': timeOfDayfromString(morningTime.split('-')[0]),
        'morningEnd': timeOfDayfromString(morningTime.split('-')[1]),
        'afternoonStart': timeOfDayfromString(afternoonTime.split('-')[0]),
        'afternoonEnd': timeOfDayfromString(afternoonTime.split('-')[1]),
        'nightStart': timeOfDayfromString(nightTime.split('-')[0]),
        'nightEnd': timeOfDayfromString(nightTime.split('-')[1]),
      };
    } catch (e) {
      log('Error getting shift times: $e');
      // Return default times if error occurs
      return {
        'morningStart': const TimeOfDay(hour: 8, minute: 0),
        'morningEnd': const TimeOfDay(hour: 12, minute: 0),
        'afternoonStart': const TimeOfDay(hour: 13, minute: 0),
        'afternoonEnd': const TimeOfDay(hour: 17, minute: 0),
        'nightStart': const TimeOfDay(hour: 18, minute: 0),
        'nightEnd': const TimeOfDay(hour: 22, minute: 0),
      };
    }
  }

  @override
  Future<void> saveShiftTimes({
    required TimeOfDay morningStart,
    required TimeOfDay morningEnd,
    required TimeOfDay afternoonStart,
    required TimeOfDay afternoonEnd,
    required TimeOfDay nightStart,
    required TimeOfDay nightEnd,
  }) async {
    _sharedPreferences.put<String>(SharedPrefsKey.morningTime,
        '${morningStart.hour}:${morningStart.minute.toString().padLeft(2, '0')}-${morningEnd.hour}:${morningEnd.minute.toString().padLeft(2, '0')}');
    _sharedPreferences.put<String>(SharedPrefsKey.afternoonTime,
        '${afternoonStart.hour}:${afternoonStart.minute.toString().padLeft(2, '0')}-${afternoonEnd.hour}:${afternoonEnd.minute.toString().padLeft(2, '0')}');
    _sharedPreferences.put<String>(SharedPrefsKey.nightTime,
        '${nightStart.hour}:${nightStart.minute.toString().padLeft(2, '0')}-${nightEnd.hour}:${nightEnd.minute.toString().padLeft(2, '0')}');
  }

  @override
  Future<Map<String, dynamic>> checkIn(CheckInOut checkIn, {DateTime? sessionStartTime, String? sessionId}) async {
    // null is false, int is minutes late
    try {
      final activeRoomId = await _getActiveRoomIdSafely();
      final normalizedRoomId =
          (checkIn.roomId != null && checkIn.roomId!.trim().isNotEmpty)
              ? checkIn.roomId!.trim()
              : activeRoomId;
      final minutesLate = _isLate(checkIn, sessionStartTime: sessionStartTime);
      final status = minutesLate > 0 ? "late" : "on_time";

      final checkInToSave =
          (normalizedRoomId != null && normalizedRoomId.isNotEmpty)
              ? checkIn.copyWith(
                  roomId: normalizedRoomId,
                  minutesLate: minutesLate,
                  status: status,
                )
              : checkIn.copyWith(
                  minutesLate: minutesLate,
                  status: status,
                );

      await _hiveService.saveCheckInOut(checkInToSave);
      
      // >>> Save PendingEduCheckIn for EDU sync <<<
      final deviceCode = await getDeviceCode();
      final localId = '${deviceCode}_${checkInToSave.time.millisecondsSinceEpoch}';
      
      final persons = await _hiveService.getAllPersons();
      final studentPerson = persons.firstWhereOrNull((p) => p.studentId == checkInToSave.studentId);
      
      final pendingEdu = PendingEduCheckIn(
        localId: localId,
        studentId: checkInToSave.studentId,
        sessionId: sessionId, // Auto-resolved by backend using roomId + timestamp if null
        roomId: checkInToSave.roomId,
        timestamp: checkInToSave.time,
        deviceId: deviceCode,
        serverUserId: studentPerson?.serverUserId,
        pin: studentPerson?.pin ?? checkInToSave.pin,
        minutesLate: minutesLate,
        status: status,
      );
      
      await savePendingEduCheckIn(pendingEdu);
      await pushLog('Saved PendingEduCheckIn to local queue: localId=$localId, studentId=${pendingEdu.studentId}, room=${pendingEdu.roomId}, pin=${pendingEdu.pin}, serverUserId=${pendingEdu.serverUserId}');

      shareEvent(AttendanceChangeEvent());
      return {
        'minutesLate': minutesLate,
      };
    } catch (e, s) {
      await pushLog('Error in checkIn: $e\n$s');
      log(
        'Error in checkIn: $e',
        stackTrace: s,
      );
      return {
        'errorMessage': 'Lỗi khi checkin',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> checkOut(
      CheckOut checkOut, Position location) async {
    try {
      final activeRoomId = await _getActiveRoomIdSafely();
      CheckInOut checkInOut = CheckInOut(
        pin: checkOut.pin,
        name: checkOut.name,
        time: checkOut.time,
        isCheckIn: false,
        studentId: checkOut.studentId,
        latitude: location.latitude,
        longitude: location.longitude,
        roomId: activeRoomId,
      );
      await _hiveService.saveCheckInOut(checkInOut);
      shareEvent(AttendanceChangeEvent());
      return {};
    } catch (e, s) {
      await pushLog('Error in checkOut: $e\n$s');
      log(
        'Error in checkOut: $e',
        stackTrace: s,
      );
      return {
        'errorMessage': 'Lỗi khi checkout',
      };
    }
  }

  @override
  void saveServerUrl(String? domain) {
    try {
      if (domain != null) {
        _sharedPreferences.put(SharedPrefsKey.domain, domain);
        _apiClient.updateConfigBaseUrl(domain);
        saveRecentDomain(domain);
      }
    } catch (e) {
      pushLog('Error in saveDomain: $e');
      log(e.toString());
    }
  }

  @override
  List<String> getRecentDomains() {
    try {
      final recent =
          _sharedPreferences.get<List<String>>(SharedPrefsKey.recentDomains);
      if (recent == null || recent.isEmpty) {
        return const [];
      }
      return recent.where((e) => e.trim().isNotEmpty).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  void saveRecentDomain(String? domain) {
    try {
      final normalized = domain?.trim() ?? '';
      if (normalized.isEmpty) {
        return;
      }
      final current = getRecentDomains();
      final updated = <String>[
        normalized,
        ...current.where((d) => d != normalized)
      ];
      const maxRecent = 5;
      _sharedPreferences.put(
        SharedPrefsKey.recentDomains,
        updated.take(maxRecent).toList(growable: false),
      );
    } catch (e) {
      pushLog('Error in saveRecentDomain: $e');
    }
  }

  @override
  String getServerUrl() {
    try {
      final String? domain = _sharedPreferences.get(SharedPrefsKey.domain);
      if (domain != null && domain.isNotEmpty) {
        _apiClient.updateConfigBaseUrl(domain);
        getIt<BuildConfig>().setBaseUrl(domain);
        saveRecentDomain(domain);
        return domain;
      }

      final configBaseUrl = getIt<BuildConfig>().kBaseUrl.trim();
      if (configBaseUrl.isNotEmpty) {
        _apiClient.updateConfigBaseUrl(configBaseUrl);
        saveRecentDomain(configBaseUrl);
        return configBaseUrl;
      }

      return "";
    } catch (e) {
      pushLog('Error in getDomain: $e');
      return "";
    }
  }

  @override
  Future<void> clearServerRelatedData() async {
    try {
      // Clear token when domain changes to force re-login
      saveAuthToken('');
      await pushLog('Domain related data cleared');
    } catch (e) {
      await pushLog('Error in clearDomainRelatedData: $e');
    }
  }

  @override
  void saveLoginId(String? loginId) {
    try {
      _sharedPreferences.put(SharedPrefsKey.loginId, loginId);
    } catch (e) {
      pushLog('Error in saveLoginId: $e');
      log(e.toString());
    }
  }

  @override
  String getLoginId() {
    try {
      final String? loginId = _sharedPreferences.get(SharedPrefsKey.loginId);
      return loginId ?? "";
    } catch (e) {
      pushLog('Error in getLoginId: $e');
      return "";
    }
  }

  @override
  void saveUserEmail(String? email) {
    try {
      _sharedPreferences.put(SharedPrefsKey.userEmail, email);
    } catch (e) {
      pushLog('Error in saveUserEmail: $e');
      log(e.toString());
    }
  }

  @override
  String getUserEmail() {
    try {
      final String? email = _sharedPreferences.get(SharedPrefsKey.userEmail);
      if (email != null && email.trim().isNotEmpty) {
        return email.trim();
      }
      return getLoginId();
    } catch (e) {
      pushLog('Error in getUserEmail: $e');
      return "";
    }
  }

  @override
  void saveUserFullName(String? fullName) {
    try {
      _sharedPreferences.put(SharedPrefsKey.userFullName, fullName);
    } catch (e) {
      pushLog('Error in saveUserFullName: $e');
      log(e.toString());
    }
  }

  @override
  String getUserFullName() {
    try {
      final String? fullName =
          _sharedPreferences.get(SharedPrefsKey.userFullName);
      return fullName?.trim() ?? "";
    } catch (e) {
      pushLog('Error in getUserFullName: $e');
      return "";
    }
  }

  @override
  void saveAvatarPath(String? path) {
    try {
      final email = getUserEmail();
      final key = email.isNotEmpty
          ? '${SharedPrefsKey.avatarPath}_$email'
          : SharedPrefsKey.avatarPath;
      _sharedPreferences.put(key, path);
    } catch (e) {
      pushLog('Error in saveAvatarPath: $e');
      log(e.toString());
    }
  }

  @override
  String getAvatarPath() {
    try {
      final email = getUserEmail();
      final key = email.isNotEmpty
          ? '${SharedPrefsKey.avatarPath}_$email'
          : SharedPrefsKey.avatarPath;
      final String? path = _sharedPreferences.get(key);
      return path?.trim() ?? "";
    } catch (e) {
      pushLog('Error in getAvatarPath: $e');
      return "";
    }
  }

  @override
  void saveUserRole(String? role) {
    try {
      _sharedPreferences.put(SharedPrefsKey.userRole, role);
    } catch (e) {
      pushLog('Error in saveUserRole: $e');
    }
  }

  @override
  String getUserRole() {
    try {
      final String? role = _sharedPreferences.get(SharedPrefsKey.userRole);
      return role ?? "";
    } catch (e) {
      pushLog('Error in getUserRole: $e');
      return "";
    }
  }

  @override
  Future<String> getDeviceCode() async {
    try {
      final stored = _sharedPreferences.get<String>(SharedPrefsKey.deviceCode);
      if (stored != null && stored.isNotEmpty) {
        return stored;
      }
      // Generate and persist device code from ANDROID_ID
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final code = androidInfo.id;
      await _sharedPreferences.put<String>(SharedPrefsKey.deviceCode, code);
      return code;
    } catch (e) {
      pushLog('Error in getDeviceCode: $e');
      // Fallback: generate a random ID
      final fallback = 'DEVICE-${DateTime.now().millisecondsSinceEpoch}';
      await _sharedPreferences.put<String>(SharedPrefsKey.deviceCode, fallback);
      return fallback;
    }
  }

  Future<String?> _getActiveRoomIdSafely() async {
    try {
      final roomId = await getActiveRoomId();
      if (roomId == null) return null;
      final normalized = roomId.trim();
      return normalized.isEmpty ? null : normalized;
    } catch (e) {
      await pushLog('Error in _getActiveRoomIdSafely: $e');
      return null;
    }
  }

  @override
  Future<void> saveDeviceCode(String code) async {
    await _sharedPreferences.put<String>(SharedPrefsKey.deviceCode, code);
  }

  @override
  Future<void> saveActiveRoomId(String roomId) async {
    final key = await _formatWithTenantId(SharedPrefsKey.activeRoom);
    await _sharedPreferences.put<String>(key, roomId);
  }

  @override
  Future<String?> getActiveRoomId() async {
    final key = await _formatWithTenantId(SharedPrefsKey.activeRoom);
    return _sharedPreferences.get<String>(key);
  }

  @override
  Future<void> saveActiveRoomName(String roomName) async {
    final key = await _formatWithTenantId(SharedPrefsKey.activeRoomName);
    await _sharedPreferences.put<String>(key, roomName);
  }

  @override
  Future<String?> getActiveRoomName() async {
    final key = await _formatWithTenantId(SharedPrefsKey.activeRoomName);
    return _sharedPreferences.get<String>(key);
  }

  @override
  String getAuthToken() {
    try {
      final String? token = _sharedPreferences.get(SharedPrefsKey.token);
      return token ?? "";
    } catch (e) {
      pushLog('Error in getToken: $e');
      return "";
    }
  }

  @override
  void saveAuthToken(String? token) {
    try {
      _sharedPreferences.put(SharedPrefsKey.token, token);
    } catch (e) {
      pushLog('Error in saveToken: $e');
      log(e.toString());
    }
  }

  @override
  String? getRefreshToken() {
    try {
      return _sharedPreferences.get(SharedPrefsKey.refreshToken);
    } catch (e) {
      pushLog('Error in getRefreshToken: $e');
      return null;
    }
  }

  @override
  void saveRefreshToken(String? token) {
    try {
      _sharedPreferences.put(SharedPrefsKey.refreshToken, token);
    } catch (e) {
      pushLog('Error in saveRefreshToken: $e');
      log(e.toString());
    }
  }

  /// Calculate minutes late.
  ///
  /// - If [sessionStartTime] is null → session is currently active,
  ///   so the student is always on time. Returns 0.
  /// - If [sessionStartTime] is provided → it carries the **late reference time**
  ///   (i.e. `checkinWindowEnd` when the session was manually closed).
  ///   Late = check-in time minus reference. Returns 0 when on time.
  int _isLate(CheckInOut checkIn, {DateTime? sessionStartTime}) {
    try {
      if (sessionStartTime == null) {
        // Session still active → always on time
        return 0;
      }
      final checkInTime = checkIn.time;
      final diff = checkInTime.difference(sessionStartTime).inMinutes;
      return diff > 0 ? diff : 0;
    } catch (e) {
      pushLog('Error checking minutes late: $e');
      log('Error checking minutes late: $e');
      return 0;
    }
  }

  @override
  Future<bool> isRegistered(int studentId) async {
    try {
      final person = await _hiveService.getPerson(studentId);
      return person != null;
    } catch (e) {
      pushLog('Error checking if person is registered: $e');
      log('Error checking if person is registered: $e');
      return false;
    }
  }

  @override
  Future<String> getLicenseKey() async {
    try {
      final licenseKey = _sharedPreferences.get(SharedPrefsKey.licenseKey);
      if (licenseKey == null) {
        return defaultLicenseKey;
      }
      return licenseKey;
    } catch (e) {
      pushLog('Error getting license key: $e');
      log('Error getting license key: $e');
      return defaultLicenseKey;
    }
  }

  @override
  Future<void> saveLicenseKey(String licenseKey) async {
    try {
      await _sharedPreferences.put(SharedPrefsKey.licenseKey, licenseKey);
    } catch (e) {
      pushLog('Error saving license key: $e');
      log('Error saving license key: $e');
      rethrow;
    }
  }

  @override
  Future<int?> getUserId() async {
    try {
      return _sharedPreferences.get(SharedPrefsKey.userId);
    } catch (e) {
      pushLog('Error getting user ID: $e');
      log('Error getting user ID: $e');
      return null;
    }
  }

  @override
  Future<void> saveUserId(int userId) async {
    try {
      await _sharedPreferences.put(SharedPrefsKey.userId, userId);
    } catch (e) {
      pushLog('Error saving user ID: $e');
      log('Error saving user ID: $e');
      rethrow;
    }
  }

  @override
  Future<void> resetBothLatestTime() async {
    final formatKeyPull =
        await _formatWithTenantId(SharedPrefsKey.latestTimePullFaceData);
    await _sharedPreferences.put(formatKeyPull, null);
  }

  @override
  Future<bool> hasUnsyncedLocalStudents() async {
    try {
      final persons = await _hiveService.getAllPersons();
      return persons.any((person) => !person.isSynced);
    } catch (e) {
      await pushLog('Error checking for unsynced local students: $e');
      return false;
    }
  }

  @override
  Future<List<Person>> getUnsyncedLocalStudents() async {
    try {
      final persons = await _hiveService.getAllPersons();
      return persons.where((person) => !person.isSynced).toList();
    } catch (e) {
      await pushLog('Error getting unsynced local students: $e');
      return [];
    }
  }

  @override
  Future<void> syncStudentsFromServer(
      List<Student> students, String serverName) async {
    try {
      final localPersons = await _hiveService.getAllPersons();

      for (final student in students) {
        // Check if student with same PIN exists in local DB
        final existingPerson = localPersons.firstWhereOrNull(
          (person) =>
              (person.pin == student.pin &&
                  student.pin != null &&
                  student.pin!.isNotEmpty) ||
              person.studentId == student.id,
        );

        if (existingPerson != null) {
          // Update existing student with server data
          final updatedPerson = existingPerson.copyWith(
            studentId: student.id,
            name: student.name,
            pin: student.pin,
            jobTitle: student.jobTitle,
            updatedTime: DateTime.now(),
            isSynced: true,
            avatar: student.avatar,
          );
          await _hiveService.deletePerson(existingPerson.studentId);
          await _hiveService.savePerson(updatedPerson);
          await _faceNative.updatePerson(existingPerson.studentId, student.name,
              newId: student.id);

          // Update all CheckInOut records with the new studentId
          final allCheckInOuts = await _hiveService.getAllCheckInOuts();
          final checkInOutsToUpdate = allCheckInOuts
              .where((checkInOut) =>
                  checkInOut.studentId == existingPerson.studentId)
              .toList();

          for (final checkInOut in checkInOutsToUpdate) {
            final updatedCheckInOut = checkInOut.copyWith(
              studentId: student.id,
              name: student.name,
            );
            await _hiveService.updateCheckInOut(updatedCheckInOut);
          }
        } else {
          // Create new student in local DB
          final newPerson = Person(
            studentId: student.id,
            name: student.name,
            pin: student.pin,
            jobTitle: student.jobTitle,
            updatedTime: DateTime.now(),
            isSynced: true,
            avatar: student.avatar,
          );
          await _hiveService.savePerson(newPerson);
        }
      }
    } catch (e) {
      await pushLog('Error syncing students from server: $e');
      rethrow;
    }
  }

  @override
  Future<void> cloneDataFromPreviousTenant(
      int oldTenantId, int newTenantId) async {
    try {
      await pushLog(
          'Attempting to clone data from tenant $oldTenantId to $newTenantId');

      // Check if old and new tenant IDs are different
      if (oldTenantId == newTenantId) {
        await pushLog('Old and new tenant IDs are the same, skipping clone');
        return;
      }

      // Clone data using HiveService
      await _hiveService.cloneDataFromOldTenant(
        oldTenantId.toString(),
        newTenantId.toString(),
      );

      await pushLog('Successfully cloned data from previous tenant');
    } catch (e, stackTrace) {
      await pushLog('Error cloning data from previous tenant: $e\n$stackTrace');
      // Don't rethrow - we don't want to block login if cloning fails
    }
  }

  @override
  Future<void> clearAllData() async {
    try {
      await pushLog('Starting to clear all local data');

      // Clear all persons from Hive
      await _hiveService.clearPersons();
      await pushLog('Cleared all persons from Hive');

      await _hiveService.clearCheckInOut();
      await pushLog('Cleared all check-in/out records');

      // Clear all EDU pending check-ins
      await _hiveService.clearAllEduCheckIns();
      await pushLog('Cleared all pending EDU sync records');

      // Get all persons to remove their face embeddings
      final allRecords = await _faceNative.getAllImages();
      final empIds = allRecords.map((record) => record.empId).toSet().toList();

      // Remove face embeddings for each student
      for (final empId in empIds) {
        await _faceNative.removeImages(empId);
      }
      await pushLog(
          'Cleared all face embeddings for ${empIds.length} students');

      await pushLog('Successfully cleared all local data');
    } catch (e, stackTrace) {
      await pushLog('Error clearing all local data: $e\n$stackTrace');
      rethrow;
    }
  }

  // --- EDU Pending Check-In (offline queue) ---

  @override
  Future<void> savePendingEduCheckIn(PendingEduCheckIn item) async {
    try {
      await _hiveService.savePendingEduCheckIn(item);
    } catch (e) {
      await pushLog('Error in savePendingEduCheckIn: $e');
      rethrow;
    }
  }

  @override
  Future<List<PendingEduCheckIn>> getPendingEduCheckIns() async {
    try {
      return await _hiveService.getPendingEduCheckIns();
    } catch (e) {
      await pushLog('Error in getPendingEduCheckIns: $e');
      return [];
    }
  }

  @override
  Future<void> markEduCheckInSynced(String localId) async {
    try {
      await _hiveService.markEduCheckInSynced(localId);
    } catch (e) {
      await pushLog('Error in markEduCheckInSynced: $e');
    }
  }

  @override
  Future<void> incrementEduRetryCount(String localId) async {
    try {
      await _hiveService.incrementEduRetryCount(localId);
    } catch (e) {
      await pushLog('Error in incrementEduRetryCount: $e');
    }
  }

  @override
  Future<void> clearSyncedEduCheckIns() async {
    try {
      await _hiveService.clearSyncedEduCheckIns();
    } catch (e) {
      await pushLog('Error in clearSyncedEduCheckIns: $e');
    }
  }

  @override
  Future<void> clearAllEduCheckIns() async {
    try {
      await _hiveService.clearAllEduCheckIns();
    } catch (e) {
      await pushLog('Error in clearAllEduCheckIns: $e');
    }
  }
}
