import 'dart:convert';
import 'dart:developer';
import 'dart:io';
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
import 'package:face_time_keeping/entities/employee.dart';
import 'package:face_time_keeping/entities/face_data.dart';
import 'package:face_time_keeping/entities/person.dart';
import 'package:face_time_keeping/entities/sync_face_schedule.dart';
import 'package:face_time_keeping/entities/sync_response.dart';
import 'package:face_time_keeping/entities/sync_schedule.dart';
import 'package:face_time_keeping/entities/tenant.dart';
import 'package:face_time_keeping/utils/csv_util.dart';
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
  void saveLoginOdooId(String? loginId);
  String getLoginOdooId();
  void saveUserEmail(String? email);
  String getUserEmail();
  void saveUserFullName(String? fullName);
  String getUserFullName();
  String getOdooToken();
  void saveOdooToken(String? token);
  void saveOdooDomain(String? domain);
  String getOdooDomain();
  List<String> getRecentDomains();
  void saveRecentDomain(String? domain);
  Future<void> clearOdooDomainRelatedData();
  Future<void> initApp();
  Future<Map<String, dynamic>> checkIn(CheckInOut checkIn);
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
  Future<bool> isRegistered(int employeeId);
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
  Future<String> getOdooDbName();
  Future<void> saveOdooDbName(String dbName);
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
  Future<bool> hasUnsyncedLocalEmployees();
  Future<List<Person>> getUnsyncedLocalEmployees();
  Future<void> syncEmployeesFromServer(
      List<Employee> employees, String serverName);
  Future<void> cloneDataFromPreviousTenant(int oldTenantId, int newTenantId);
  Future<void> clearAllData();
  void saveAvatarPath(String? path);
  String getAvatarPath();
}

@LazySingleton(as: LocalService)
class LocalServiceImplement implements LocalService {
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
            persons.firstWhereOrNull((e) => e.employeeId == faceData.empId);
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
                    employeeId: faceData.empId,
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
  Future<String> getOdooDbName() async {
    return _sharedPreferences.get(SharedPrefsKey.dbName) ?? '';
  }

  @override
  Future<void> saveOdooDbName(String dbName) async {
    await _sharedPreferences.put(SharedPrefsKey.dbName, dbName);
  }

  @override
  Future<File> exportModelToJsonFile({List<Person>? persons}) async {
    try {
      late final records;
      if (persons == null || persons.isEmpty) {
        records = await _faceNative.getAllImages();
      } else {
        final personIds = persons.map((e) => e.employeeId).toList();
        records = await _faceNative.getFaceImageRecordByListEmpId(personIds);
      }
      final map = <int, List<List<double>>>{};
      for (final record in records) {
        map.putIfAbsent(record.empId, () => []);
        map[record.empId]!.add(record.faceEmbedding);
      }
      final mapUpdatedTime = <int, DateTime>{};
      for (final person in persons ?? []) {
        mapUpdatedTime[person.employeeId] = person.updatedTime;
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
        bulkUsers.putIfAbsent(checkInOut.employeeId.toString(), () => []);
        bulkUsers[checkInOut.employeeId.toString()]!.add(checkInOut);
      }
      return bulkUsers.values
          .map((e) => BulkUser(
              employeeId: e.first.employeeId, pin: e.first.pin, checkInOuts: e))
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
      final domain = getOdooDomain();
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
  Future<Map<String, dynamic>> checkIn(CheckInOut checkIn) async {
    // null is false, int is minutes late
    try {
      await _hiveService.saveCheckInOut(checkIn);
      final minutesLate = await _isLate(checkIn);
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
      CheckInOut checkInOut = CheckInOut(
        pin: checkOut.pin,
        name: checkOut.name,
        time: checkOut.time,
        isCheckIn: false,
        employeeId: checkOut.employeeId,
        latitude: location.latitude,
        longitude: location.longitude,
      );
      await _hiveService.saveCheckInOut(checkInOut);
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
  void saveOdooDomain(String? domain) {
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
  String getOdooDomain() {
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
  Future<void> clearOdooDomainRelatedData() async {
    try {
      // Clear token when domain changes to force re-login
      saveOdooToken('');
      await pushLog('Domain related data cleared');
    } catch (e) {
      await pushLog('Error in clearDomainRelatedData: $e');
    }
  }

  @override
  void saveLoginOdooId(String? loginId) {
    try {
      _sharedPreferences.put(SharedPrefsKey.loginId, loginId);
    } catch (e) {
      pushLog('Error in saveLoginId: $e');
      log(e.toString());
    }
  }

  @override
  String getLoginOdooId() {
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
      return getLoginOdooId();
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
      final key = email.isNotEmpty ? '${SharedPrefsKey.avatarPath}_$email' : SharedPrefsKey.avatarPath;
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
      final key = email.isNotEmpty ? '${SharedPrefsKey.avatarPath}_$email' : SharedPrefsKey.avatarPath;
      final String? path = _sharedPreferences.get(key);
      return path?.trim() ?? "";
    } catch (e) {
      pushLog('Error in getAvatarPath: $e');
      return "";
    }
  }

  @override
  String getOdooToken() {
    try {
      final String? token = _sharedPreferences.get(SharedPrefsKey.token);
      return token ?? "";
    } catch (e) {
      pushLog('Error in getToken: $e');
      return "";
    }
  }

  @override
  void saveOdooToken(String? token) {
    try {
      _sharedPreferences.put(SharedPrefsKey.token, token);
    } catch (e) {
      pushLog('Error in saveToken: $e');
      log(e.toString());
    }
  }

  Future<int> _isLate(CheckInOut checkIn) async {
    try {
      final shiftTimes = await getShiftTimes();
      final checkInTime = TimeOfDay.fromDateTime(checkIn.time);

      // Determine which shift this check-in belongs to based on time
      final morningStart = shiftTimes['morningStart']!;
      final morningEnd = shiftTimes['morningEnd']!;
      final afternoonStart = shiftTimes['afternoonStart']!;
      final afternoonEnd = shiftTimes['afternoonEnd']!;
      final nightStart = shiftTimes['nightStart']!;
      final nightEnd = shiftTimes['nightEnd']!;

      // Helper function to calculate minutes difference between two TimeOfDay
      int getMinutesDifference(TimeOfDay laterTime, TimeOfDay earlierTime) {
        final laterMinutes = laterTime.hour * 60 + laterTime.minute;
        final earlierMinutes = earlierTime.hour * 60 + earlierTime.minute;
        return laterMinutes - earlierMinutes;
      }

      // Helper function to check if time is within a shift range
      bool isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
        final timeMinutes = time.hour * 60 + time.minute;
        final startMinutes = start.hour * 60 + start.minute;
        final endMinutes = end.hour * 60 + end.minute;

        // Handle cases where shift spans midnight
        if (endMinutes < startMinutes) {
          return timeMinutes >= startMinutes || timeMinutes <= endMinutes;
        } else {
          return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
        }
      }

      // Check which shift this check-in belongs to and calculate lateness
      // Morning shift
      if (isTimeInRange(checkInTime, morningStart, morningEnd)) {
        final minutesLate = getMinutesDifference(checkInTime, morningStart);
        return minutesLate > 0 ? minutesLate : 0;
      }

      // Afternoon shift
      if (isTimeInRange(checkInTime, afternoonStart, afternoonEnd)) {
        final minutesLate = getMinutesDifference(checkInTime, afternoonStart);
        return minutesLate > 0 ? minutesLate : 0;
      }

      // Night shift
      if (isTimeInRange(checkInTime, nightStart, nightEnd)) {
        final minutesLate = getMinutesDifference(checkInTime, nightStart);
        return minutesLate > 0 ? minutesLate : 0;
      }

      // Default case: return 0 if no clear shift match
      return 0;
    } catch (e) {
      pushLog('Error checking minutes late: $e');
      log('Error checking minutes late: $e');
      return 0; // Default to not late if error occurs
    }
  }

  @override
  Future<bool> isRegistered(int employeeId) async {
    try {
      final person = await _hiveService.getPerson(employeeId);
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
  Future<bool> hasUnsyncedLocalEmployees() async {
    try {
      final persons = await _hiveService.getAllPersons();
      return persons.any((person) => !person.isSynced);
    } catch (e) {
      await pushLog('Error checking for unsynced local employees: $e');
      return false;
    }
  }

  @override
  Future<List<Person>> getUnsyncedLocalEmployees() async {
    try {
      final persons = await _hiveService.getAllPersons();
      return persons.where((person) => !person.isSynced).toList();
    } catch (e) {
      await pushLog('Error getting unsynced local employees: $e');
      return [];
    }
  }

  @override
  Future<void> syncEmployeesFromServer(
      List<Employee> employees, String serverName) async {
    try {
      final localPersons = await _hiveService.getAllPersons();

      for (final employee in employees) {
        // Check if employee with same PIN exists in local DB
        final existingPerson = localPersons.firstWhereOrNull(
          (person) =>
              (person.pin == employee.pin &&
                  employee.pin != null &&
                  employee.pin!.isNotEmpty) ||
              person.employeeId == employee.id,
        );

        if (existingPerson != null) {
          // Update existing employee with server data
          final updatedPerson = existingPerson.copyWith(
            employeeId: employee.id,
            name: employee.name,
            pin: employee.pin,
            jobTitle: employee.jobTitle,
            updatedTime: DateTime.now(),
            isSynced: true,
            avatar: employee.avatar,
          );
          await _hiveService.deletePerson(existingPerson.employeeId);
          await _hiveService.savePerson(updatedPerson);
          await _faceNative.updatePerson(
              existingPerson.employeeId, employee.name,
              newId: employee.id);

          // Update all CheckInOut records with the new employeeId
          final allCheckInOuts = await _hiveService.getAllCheckInOuts();
          final checkInOutsToUpdate = allCheckInOuts
              .where((checkInOut) =>
                  checkInOut.employeeId == existingPerson.employeeId)
              .toList();

          for (final checkInOut in checkInOutsToUpdate) {
            final updatedCheckInOut = checkInOut.copyWith(
              employeeId: employee.id,
              name: employee.name,
            );
            await _hiveService.updateCheckInOut(updatedCheckInOut);
          }
        } else {
          // Create new employee in local DB
          final newPerson = Person(
            employeeId: employee.id,
            name: employee.name,
            pin: employee.pin,
            jobTitle: employee.jobTitle,
            updatedTime: DateTime.now(),
            isSynced: true,
            avatar: employee.avatar,
          );
          await _hiveService.savePerson(newPerson);
        }
      }
    } catch (e) {
      await pushLog('Error syncing employees from server: $e');
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

      // Clear all check-in/out records
      await _hiveService.clearCheckInOut();
      await pushLog('Cleared all check-in/out records');

      // Get all persons to remove their face embeddings
      final allRecords = await _faceNative.getAllImages();
      final empIds = allRecords.map((record) => record.empId).toSet().toList();

      // Remove face embeddings for each employee
      for (final empId in empIds) {
        await _faceNative.removeImages(empId);
      }
      await pushLog(
          'Cleared all face embeddings for ${empIds.length} employees');

      await pushLog('Successfully cleared all local data');
    } catch (e, stackTrace) {
      await pushLog('Error clearing all local data: $e\n$stackTrace');
      rethrow;
    }
  }
}
