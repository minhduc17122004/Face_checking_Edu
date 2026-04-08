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
  import 'package:face_time_keeping/entities/import_mode.dart';
  import 'package:face_time_keeping/entities/pending_edu_check_in.dart';
  import 'package:face_time_keeping/entities/person.dart';
  import 'package:face_time_keeping/entities/sync_face_schedule.dart';
  import 'package:face_time_keeping/entities/sync_response.dart';
  import 'package:face_time_keeping/entities/sync_schedule.dart';
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
  import 'package:face_time_keeping/common/utils/extensions/string_extension.dart';

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
    Future<Map<String, dynamic>> checkIn(CheckInOut checkIn,
        {DateTime? sessionStartTime, String? sessionId});
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
    Future<File> exportModelToJsonFile({List<Person>? persons});
    Future<List<Person>> getPersonsUnSynced();
    Future<DateTime?> getLatestTimePullFaceData();
    Future<void> saveLatestTimePullFaceData(DateTime latestTime);
    Future<int> importFaceData(List<FaceData> faceDataList);
    Future<void> resetBothLatestTime();
    Future<void> setPersonSynced(int personId);
    Future<void> applyPushMetadata(List<dynamic> itemsMeta);
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
    Future<int> purgeInvalidEduCheckIns();

    // --- Face sync lock (TTL-based, cross-isolate safe) ---
    Future<String?> acquireFaceSyncLock();
    Future<void> releaseFaceSyncLock(String token);

    // --- Watermark ---
    Future<void> updateWatermarkSafely({
      required List<FaceData> allValidFaceData,
      required List<FaceData> successItems,
      required List<FaceData> failedItems,
      required List<FaceData> unprocessedItems,
    });

    // --- Face-reset skip list ---
    void clearProcessedKeyForStudent(int empId);

    /// Adds [pins] to the skip list so the next importFaceData cycle ignores them.
    Future<void> addFaceResetSkipPins(List<String> pins);

    /// Returns the current skip list.
    Future<Set<String>> getFaceResetSkipPins();

    /// Clears the skip list (called automatically after one importFaceData run).
    Future<void> clearFaceResetSkipPins();

    // --- Pending recovery student ids ---
    Future<void> addPendingRecoveryStudentIds(List<String> ids);
    Future<Set<String>> getPendingRecoveryStudentIds();
    Future<void> clearPendingRecoveryStudentIds();
  }

  @LazySingleton(as: LocalService)
  class LocalServiceImplement with EventBusMixin implements LocalService {
    LocalServiceImplement(this._sharedPreferences, this._apiClient,
        this._hiveService, this._csvUtil) {
      _faceNative = FaceNative();
    }

    Person? _findStudentPerson(List<Person> persons, int studentId, String name, String? pin) {
      // 1. Priority 1: Exact ID match (ignore if SDK returned 0)
      if (studentId != 0) {
        final p = persons.firstWhereOrNull((p) => p.studentId == studentId);
        if (p != null) return p;
      }

      // 2. Priority 2: PIN match
      if (pin != null && pin.isNotEmpty) {
        final p = persons.firstWhereOrNull((p) => p.pin == pin);
        if (p != null) return p;
      }

      // 3. Priority 3 & 4: Name match
      if (name.isNotEmpty && name != 'Unknown') {
        // Helper to normalize spaces: '  Lê    Anh  ' -> 'lê anh'
        String normalizeString(String s) {
          return s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        }

        final normalizedSearchName = normalizeString(name);
        
        // 3a. Exact normalized name match
        var p = persons.firstWhereOrNull((p) => normalizeString(p.name ?? '') == normalizedSearchName);
        if (p != null) return p;
        
        // 3b. Bulletproof Fallback: Diacritic-insensitive normalized match
        final searchNameNoDia = normalizedSearchName.removeVietnameseDiacritics();
        p = persons.firstWhereOrNull((p) => 
            normalizeString(p.name ?? '').removeVietnameseDiacritics() == searchNameNoDia);
        if (p != null) return p;
      }

      return null;
    }

    final SharedPrefs _sharedPreferences;
    final HiveService _hiveService;
    final ApiClient _apiClient;
    //{"licenseKey":"paraceltech","owner":"Paracel","issuedDate":"2025-08-29T10:09:48","licenseExpiredDate":"2026-05-20T23:59:59"}
    static const defaultLicenseKey =
        'WHF4enplZXB1STZpV0dQVFBlRWpvamFtUVRVTUEwOHhIY1B4Rm5FYUJBVkpYM2trVG43bmdweHdOazFKdVRkL0Z1L3NiNXRqYzhiaGxRbWRMUXFaOGYwazJ5dHZnSm05ZFE4QkNJSjVWY212azlRRFNjMXNheDJHbjUzL3Q0MHRiajZueXlPR1Jua0s1WjlvVkFwY096bUlBeXBET0JSa0J4MEtKTUNNUlJwZXdOMmlVWU4rUGo2aUVNc3pmRTBGNjFVQWJ5NUpCbFdzWi92d1p5UVVCMitFZ0RmMnRIRWVpdHpSWHVpQW12SXVURTVORTlyMDRzY2plQXorWVQyb0tqaDBiRlo4L21ETXBmVy9PeG9sSWpXV01zZzVYQUNBTXdTRG4vSWlrOFJWQ2tMY0R4T0Y5NXJlS08zd2pmR1Rwb05sZEdwcFo2UHo1Ty9kWFFKODRRPT06dWVJMGtjZVZCYmlXOW1rcU1KMVRqNTIvUDNNWHA3MmttcXdOUEVkVW5COEVzdHhlQVR0Z3FEaU9EaXo3R3lzdnNXWWMyNS9IQ2YrVnptL0xJZUdYNEsyU25MczlOcHZXRER2QWJWbk5aNVYvZjBwaDUwSG5qWkpFc2VBREY4dVFxdDZ5NzhnUTVHTHp3QkYrdS9XUU9OSmRnRHh6aEVFV2t0cmp0QkhWVmZRPQ==';

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

    // ── Thêm Random / Math dependency ──
    // Để code không báo thiếu thư viện sinh ngẫu nhiên
    String _generateToken() {
      return 'lock_${DateTime.now().millisecondsSinceEpoch}';
    }

    // ── Face sync lock (TTL-based) ───────────────────────────────────────────
    @override
    Future<String?> acquireFaceSyncLock() async {
      try {
        final raw =
            _sharedPreferences.get<String>(SharedPrefsKey.faceSyncLockExpiresAt);
        if (raw != null && raw.contains('|')) {
          final parts = raw.split('|');
          final expiresAt = DateTime.tryParse(parts[1]);
          if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
            return null; // Lock is still active
          }
        }
        final token = _generateToken();
        final newExpiry =
            DateTime.now().add(const Duration(minutes: 5)).toIso8601String();
        await _sharedPreferences.put(
            SharedPrefsKey.faceSyncLockExpiresAt, '$token|$newExpiry');
        return token;
      } catch (e) {
        await pushLog('Error acquiring face sync lock: $e');
        return 'fail-open-token'; // Fail-open locally if prefs fail
      }
    }

    @override
    Future<void> releaseFaceSyncLock(String token) async {
      try {
        final raw =
            _sharedPreferences.get<String>(SharedPrefsKey.faceSyncLockExpiresAt);
        if (raw != null && raw.startsWith('$token|')) {
          await _sharedPreferences.clearKey(SharedPrefsKey.faceSyncLockExpiresAt);
        }
      } catch (e) {
        await pushLog('Error releasing face sync lock: $e');
      }
    }

    // ── Face-reset skip list ─────────────────────────────────────────────────
    @override
    Future<void> addFaceResetSkipPins(List<String> pins) async {
      final current = await getFaceResetSkipPins();
      final merged = {...current, ...pins.where((p) => p.isNotEmpty)};
      await _sharedPreferences.put(
          SharedPrefsKey.faceResetSkipPins, merged.join(','));
    }

    @override
    Future<Set<String>> getFaceResetSkipPins() async {
      final raw =
          _sharedPreferences.get<String>(SharedPrefsKey.faceResetSkipPins);
      if (raw == null || raw.isEmpty) return {};
      return raw.split(',').where((s) => s.isNotEmpty).toSet();
    }

    @override
    Future<void> clearFaceResetSkipPins() async {
      await _sharedPreferences.put(SharedPrefsKey.faceResetSkipPins, null);
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

    /// Applies server-generated metadata from a successful Push (PUT) response.
    ///
    /// For each item in [itemsMeta], updates the local Hive record with:
    ///   - `isSynced = true`
    ///   - `updatedTime` & `serverUpdatedAt` = server's `updated_at`
    ///   - `embeddingHash` = server's `server_hash`
    ///
    /// Then advances the watermark (lastSyncTime) to the max `updated_at` so
    /// the next Pull (GET) won't re-download records the App just pushed.
    @override
    Future<void> applyPushMetadata(List<dynamic> itemsMeta) async {
      try {
        DateTime? maxServerTime;

        for (final raw in itemsMeta) {
          if (raw is! Map<String, dynamic>) continue;

          final id = raw['id'] as int?;
          final updatedAtStr = raw['updated_at'] as String?;
          final serverHash = raw['server_hash'] as String?;

          if (id == null || updatedAtStr == null) continue;

          // Parse server timestamp — always UTC
          final serverTime = DateTime.tryParse(updatedAtStr)?.toUtc();
          if (serverTime == null) {
            await pushLog(
                '[applyPushMetadata] Skipped id=$id: unparseable updated_at=$updatedAtStr');
            continue;
          }

          // Track max timestamp for watermark
          if (maxServerTime == null || serverTime.isAfter(maxServerTime)) {
            maxServerTime = serverTime;
          }

          // Update local Hive person record
          final person = await _hiveService.getPerson(id);
          if (person == null) {
            await pushLog(
                '[applyPushMetadata] Skipped id=$id: not found in local DB');
            continue;
          }

          await _hiveService.updatePerson(person.copyWith(
            isSynced: true,
            updatedTime: serverTime,
            serverUpdatedAt: serverTime,
            embeddingHash: serverHash ?? person.embeddingHash,
          ));

          await pushLog(
              '[applyPushMetadata] Updated id=$id → serverUpdatedAt=$serverTime, hash=${serverHash?.substring(0, 8) ?? "null"}');
        }

        // Advance watermark ONLY IF we have pulled before (currentWatermark != null)
        if (maxServerTime != null) {
          final currentWatermark = await getLatestTimePullFaceData();
          if (currentWatermark != null &&
              maxServerTime.isAfter(currentWatermark)) {
            await saveLatestTimePullFaceData(maxServerTime);
            await pushLog(
                '[applyPushMetadata] Watermark advanced: $currentWatermark → $maxServerTime');
          } else if (currentWatermark == null) {
            await pushLog(
                '[applyPushMetadata] Skipped watermark advance: Initial pull has not happened yet (Watermark is null). Preserving null to fetch full history.');
          }
        }
      } catch (e) {
        // Non-fatal: push already succeeded, metadata update is best-effort
        await pushLog('Error in applyPushMetadata: $e');
      }
    }

    // Idempotency In-Memory Cache — stores iKey for successfully imported items
    // Key format: "empId_serverTimestampMs"
    // IMPORTANT: For RECOVER mode, iKey is NOT cached so re-sync always re-imports
    final Set<String> _processedKeys = {};

    /// Called by BLoC after reset face so next sync always re-imports that student.
    void clearProcessedKeyForStudent(int empId) {
      _processedKeys.removeWhere((k) => k.startsWith('${empId}_'));
      pushLog(
          '[SYNC DEBUG] Cleared processedKeys for empId=$empId → will force recover on next sync');
    }

    // ── Chữa lỗi consistency Native ──
    Future<bool> _isPhysicalFaceMissing(int empId) async {
      final faces = await _faceNative.getFaceImageRecordByListEmpId([empId]);
      return faces.isEmpty;
    }

    // ── Helper: Retry logic ─────────────────────
    Future<void> _withRetry(Future<void> Function() operation) async {
      const backoffs = [100, 300, 1000];
      for (int i = 0; i < backoffs.length + 1; i++) {
        try {
          await operation();
          return;
        } catch (e) {
          if (i == backoffs.length) rethrow; // Nếu hết lần thử thứ 3
          await Future.delayed(Duration(milliseconds: backoffs[i]));
        }
      }
    }

    // ── Helper: Decide how to import a single face record ──────────
    Future<ImportMode> _shouldImport({
      required Person? person,
      required FaceData faceData,
      required bool hasLocalEmbedding,
    }) async {
      if (person == null) return ImportMode.fullImport; // New user

      // CONSISTENCY CHECK: Check if hive says true but actual FaceNative data lost
      bool actualHasEmbedding = hasLocalEmbedding;
      if (actualHasEmbedding) {
        final isLost = await _isPhysicalFaceMissing(person.studentId);
        if (isLost) {
          await pushLog(
              '[SYNC] Consistency mismatch: empId=${person.studentId} hasLocalEmbedding=true but FaceNative is empty -> RECOVER');
          actualHasEmbedding = false;
        }
      }

      // PHYSICAL CHECK (highest priority)
      if (!actualHasEmbedding) return ImportMode.recover;

      // HASH CHECK (content comparison)
      if (person.embeddingHash != faceData.embeddingHash)
        return ImportMode.fullImport;

      // TIMESTAMP CHECK (metadata freshness)
      if (faceData.serverUpdatedAt.isAfter(person.serverUpdatedAt ?? DateTime(0)))
        return ImportMode.metadataOnly;

      return ImportMode.skip; // No changes
    }

    Future<Person> _migratePersonId(Person person, int newEmpId) async {
      await pushLog(
          '[importFaceData] Migrating local studentId ${person.studentId} → $newEmpId for "${person.name}" to match server');
      final oldId = person.studentId;
      final migratedPerson = person.copyWith(studentId: newEmpId);

      await _hiveService.deletePerson(oldId);
      await _hiveService.savePerson(migratedPerson);
      await _faceNative.updatePerson(oldId, person.name ?? "Unknown",
          newId: newEmpId);

      return migratedPerson;
    }

    Future<void> _doFullImport(Person? person, FaceData faceData) async {
      if (faceData.listFaceEmbedding.isEmpty) return;

      final newRecords = faceData.listFaceEmbedding
          .where((e) => e.isNotEmpty)
          .map((e) => FaceImageRecord(
                personName: faceData.personName ?? 'Unknown',
                empId: faceData.empId,
                faceEmbedding: e,
              ))
          .toList();

      if (newRecords.isEmpty) return;

      await _withRetry(() async {
        if (person != null) {
          await _faceNative.removeImages(person.studentId);
        }
        await _faceNative.addAllRecords(newRecords);

        // Save person metadata
        final updatedPerson = person?.copyWith(
              updatedTime: faceData.serverUpdatedAt,
              serverUpdatedAt: faceData.serverUpdatedAt,
              embeddingHash: faceData.embeddingHash,
              pin: faceData.studentCode ?? person.pin,
              hasLocalEmbedding: true,
              isSynced: true,
            ) ??
            Person(
              studentId: faceData.empId,
              updatedTime: faceData.serverUpdatedAt,
              serverUpdatedAt: faceData.serverUpdatedAt,
              embeddingHash: faceData.embeddingHash,
              name: faceData.personName ?? 'Unknown',
              pin: faceData.studentCode,
              hasLocalEmbedding: true,
              isSynced: true,
            );

        await _hiveService.savePerson(updatedPerson);
      });
    }

    @override
    Future<int> importFaceData(List<FaceData> rawFaceDataList) async {
      final startTimeMs = DateTime.now().millisecondsSinceEpoch;
      final token = await acquireFaceSyncLock();
      if (token == null) {
        await pushLog('[importFaceData] Skipped — face sync lock is active');
        return 0;
      }

      try {
        // Metric tracking
        final totalReceived = rawFaceDataList.length;
        int totalProcessed = 0;
        int totalSkipped = 0;
        int totalImported = 0;
        // Counts ONLY fullImport + recover (actual embedding writes)
        int totalFullImported = 0;
        final successItems = <FaceData>[];
        final failedItems = <FaceData>[];
        final unprocessedItems = <FaceData>[];

        // Defensive filtering out invalid data directly from the raw array
        final validRawData = <FaceData>[];
        for (final fd in rawFaceDataList) {
          if (fd.embeddingHash == null || fd.embeddingHash!.isEmpty) {
            await pushLog(
                '[SYNC ERROR] Skipped empId=${fd.empId}: embedding_hash is null/empty');
            continue;
          }
          if (fd.listFaceEmbedding.isEmpty) {
            await pushLog(
                '[SYNC WARNING] empId=${fd.empId} server states no embedding found');
          }
          validRawData.add(fd);
        }

        // 1. DEDUP INPUT — keep the newest record per student_id
        final Map<int, FaceData> dedupMap = {};
        for (final fd in validRawData) {
          final existing = dedupMap[fd.empId];
          if (existing == null ||
              fd.serverUpdatedAt.isAfter(existing.serverUpdatedAt)) {
            dedupMap[fd.empId] = fd;
          }
        }
        final faceDataList = dedupMap.values.toList();

        // 2. LOAD ALL LOCAL PERSONS
        final persons = await _hiveService.getAllPersons();
        final personById = {for (final p in persons) p.studentId: p};
        final personByPin = {
          for (final p in persons)
            if (p.pin?.isNotEmpty == true) p.pin!: p
        };
        final personByName = {
          for (final p in persons)
            if (p.name?.isNotEmpty == true) p.name!.trim().toLowerCase(): p
        };

        // 3. PRE-FILTER & IDEMPOTENCY CULLING
        await pushLog(
            '[SYNC DEBUG] Pre-filter: total_deduped=${faceDataList.length}, pendingRecoveryIds=${(await getPendingRecoveryStudentIds()).join(",")}');
        final toProcess = faceDataList.where((fd) {
          final p = personById[fd.empId];

          // If local face was reset (hasLocalEmbedding=false), ALWAYS process — even if idempotency key cached
          if (p != null && !p.hasLocalEmbedding) {
            // Clear stale iKey so recover always runs
            _processedKeys.removeWhere((k) => k.startsWith('${fd.empId}_'));
            return true; // RECOVER — bypass idempotency
          }

          // Idempotency check (only for non-recover cases):
          final iKey = '${fd.empId}_${fd.serverUpdatedAt.millisecondsSinceEpoch}';
          if (_processedKeys.contains(iKey)) {
            totalSkipped++;
            return false; // Already imported in previous sync cycle
          }

          if (p == null) return true; // New student
          if (p.embeddingHash != fd.embeddingHash) return true; // Hash mismatch

          // Hash matches — only process if server has genuinely newer metadata
          // If serverUpdatedAt is unknown locally (null) the first pull will save it;
          // subsequent pulls where timestamps also match are safe to skip.
          final localTs = p.serverUpdatedAt;
          if (localTs == null) return true; // First time: save metadata
          if (fd.serverUpdatedAt.isAfter(localTs)) return true; // Newer metadata

          totalSkipped++;
          return false; // Hash + timestamp identical → nothing to do
        }).toList();

        await pushLog(
            '[SYNC DEBUG] toProcess=${toProcess.length}, total_skipped_prefilter=$totalSkipped');
        for (final fd in toProcess) {
          final p = personById[fd.empId];
          await pushLog(
              '[SYNC DEBUG] queued empId=${fd.empId} hasLocalEmbedding=${p?.hasLocalEmbedding} localHash=${p?.embeddingHash?.substring(0, 8) ?? "null"} serverHash=${fd.embeddingHash?.substring(0, 8) ?? "null"}');
        }

        unprocessedItems.addAll(toProcess);

        // Clean up deprecated skip list
        final skipPins = await getFaceResetSkipPins();
        if (skipPins.isNotEmpty) {
          await clearFaceResetSkipPins();
        }

        // Purge stale native faces not in local DB
        final allNativeRecords = await _faceNative.getAllImages();
        final staleEmpIds = <int>{};
        final validLocalIds = personById.keys.toSet();
        final validLocalNames = personByName.keys.toSet();

        for (final native in allNativeRecords) {
          final nativeName = native.personName.trim().toLowerCase();
          final isValidId = validLocalIds.contains(native.empId);
          final isValidName =
              nativeName.isNotEmpty && validLocalNames.contains(nativeName);
          if (!isValidId && !isValidName) {
            staleEmpIds.add(native.empId);
          }
        }
        for (final staleId in staleEmpIds) {
          await pushLog(
              '[importFaceData] Purging stale native face empId=$staleId');
          await _faceNative.removeImages(staleId);
        }

        final watermarkBefore = await getLatestTimePullFaceData();
        const batchSize = 50;

        for (var i = 0; i < toProcess.length; i += batchSize) {
          final batch = toProcess.skip(i).take(batchSize).toList();

          for (final faceData in batch) {
            final iKey =
                '${faceData.empId}_${faceData.serverUpdatedAt.millisecondsSinceEpoch}';
            try {
              // Identity resolution
              Person? person = personById[faceData.empId] ??
                  (faceData.studentCode?.isNotEmpty == true
                      ? personByPin[faceData.studentCode]
                      : null) ??
                  (faceData.personName?.isNotEmpty == true
                      ? personByName[faceData.personName!.trim().toLowerCase()]
                      : null);

              // Migrate if needed
              if (person != null && person.studentId != faceData.empId) {
                person = await _migratePersonId(person, faceData.empId);
              }

              final mode = await _shouldImport(
                person: person,
                faceData: faceData,
                hasLocalEmbedding: person?.hasLocalEmbedding ?? false,
              );

              await pushLog(
                  '[SYNC DEBUG] empId=${faceData.empId} mode=${mode.name} hasLocalEmbedding=${person?.hasLocalEmbedding} embeddingHash_local=${person?.embeddingHash?.substring(0, 8) ?? "null"} embeddingHash_server=${faceData.embeddingHash?.substring(0, 8) ?? "null"}');
              switch (mode) {
                case ImportMode.skip:
                  totalSkipped++;
                  break;
                case ImportMode.recover:
                case ImportMode.fullImport:
                  await _doFullImport(person, faceData);
                  totalImported++;
                  totalFullImported++;
                  await pushLog(
                      '[SYNC] empId=${faceData.empId} mode=${mode.name} reason=${person == null ? "new" : "hash_mismatch/recover"} retry=0');
                  break;
                case ImportMode.metadataOnly:
                  await _withRetry(() async {
                    await _hiveService.updatePerson(person!.copyWith(
                      serverUpdatedAt: faceData.serverUpdatedAt,
                      pin: faceData.studentCode ?? person.pin,
                      isSynced: true,
                    ));
                  });
                  totalImported++;
                  await pushLog(
                      '[SYNC] empId=${faceData.empId} mode=${mode.name} reason=metadata_newer retry=0');
                  break;
              }

              _processedKeys.add(iKey);
              successItems.add(faceData);
              unprocessedItems.remove(faceData);
              totalProcessed++;
            } catch (e) {
              await pushLog('[SYNC ERROR] empId=${faceData.empId} failed: $e');
              failedItems.add(faceData);
              unprocessedItems.remove(faceData); // Even failed are un-unprocessed
              // Don't add to processed keys so it can retry next run
            }
          }
          await Future.delayed(Duration.zero); // yield batch
        }

        // 4. Update Watermark Safely
        await updateWatermarkSafely(
          allValidFaceData: faceDataList,
          successItems: successItems,
          failedItems: failedItems,
          unprocessedItems: unprocessedItems,
        );

        final durationMs = DateTime.now().millisecondsSinceEpoch - startTimeMs;
        final watermarkAfter = await getLatestTimePullFaceData();

        await pushLog(
            '[SYNC REPORT] total_received=$totalReceived, total_processed=$totalProcessed, '
            'total_skipped=$totalSkipped, total_imported=$totalImported, total_full_imported=$totalFullImported, total_failed=${failedItems.length}, '
            'duration_ms=$durationMs, watermark_before=$watermarkBefore, watermark_after=$watermarkAfter');
        return totalFullImported;
      } catch (e) {
        await pushLog('Error in importFaceData global track: $e');
        rethrow;
      } finally {
        await releaseFaceSyncLock(token);
      }
    }

    @override
    Future<void> updateWatermarkSafely({
      required List<FaceData> allValidFaceData,
      required List<FaceData> successItems,
      required List<FaceData> failedItems,
      required List<FaceData> unprocessedItems,
    }) async {
      if (allValidFaceData.isEmpty) return;

      DateTime newWatermark;

      if (failedItems.isEmpty && unprocessedItems.isEmpty) {
        // Nếu thành công tất cả (hoặc đã bị skip an toàn do cache chặn), watermark tiến lên max của TẤT CẢ bản ghi
        newWatermark = allValidFaceData
            .map((fd) => fd.serverUpdatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      } else {
        // Nếu có lỗi hay bỏ dở vòng lặp, rollback về min của 2 mảng đó trừ đi 1s
        final allBadTs =
            [...failedItems, ...unprocessedItems].map((e) => e.serverUpdatedAt);
        final minBadTs = allBadTs.reduce((a, b) => a.isBefore(b) ? a : b);
        newWatermark = minBadTs.subtract(const Duration(seconds: 1));
        await pushLog(
            '[Watermark] Notice ${failedItems.length} failed, ${unprocessedItems.length} unprocessed → rollback to $newWatermark');
      }

      final currentWatermark = await getLatestTimePullFaceData();
      if (failedItems.isEmpty &&
          unprocessedItems.isEmpty &&
          currentWatermark != null &&
          !newWatermark.isAfter(currentWatermark)) {
        return; // only step forward if cleanly successful and time advanced
      }

      await saveLatestTimePullFaceData(newWatermark);
    }

    @override
    Future<DateTime?> getLatestTimePullFaceData() async {
      try {
        final key = SharedPrefsKey.latestTimePullFaceData;
        final latestTimeStr = _sharedPreferences.get(key);
        if (latestTimeStr == null) return null;

        // FIX: Ensure Dart parses it as UTC.
        final formattedStr =
            latestTimeStr.endsWith('Z') ? latestTimeStr : '${latestTimeStr}Z';
        return DateTime.parse(formattedStr).toUtc();
      } catch (e) {
        await pushLog('Error in getLatestTimePullFaceData: $e');
        rethrow;
      }
    }

    @override
    Future<void> saveLatestTimePullFaceData(DateTime latestTime) async {
      final key = SharedPrefsKey.latestTimePullFaceData;
      // FIX: Force to UTC and explicitly append 'Z'
      final utcString =
          '${latestTime.toUtc().toIso8601String().split('.').first}Z';
      await _sharedPreferences.put(key, utcString);
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

        // Build empId→personName from FaceNative records (most reliable source)
        final Map<int, String?> faceNameMap = {
          for (final r in records)
            if (r.personName.isNotEmpty) r.empId: r.personName,
        };

        // Load Hive persons to get pin (studentCode) and updatedTime.
        // When persons==null (full export) we must query Hive ourselves.
        final allPersons = (persons != null && persons.isNotEmpty)
            ? persons
            : await _hiveService.getAllPersons();

        final mapUpdatedTime = <int, DateTime>{};
        final mapPin = <int, String?>{};
        final mapName = <int, String?>{};
        for (final person in allPersons) {
          mapUpdatedTime[person.studentId] = person.updatedTime;
          mapPin[person.studentId] = person.pin;
          mapName[person.studentId] = person.name;
        }

        final faceDataList = map.entries
            .map((e) => FaceData(
                  empId: e.key,
                  updatedTime: mapUpdatedTime[e.key] ?? DateTime.now(),
                  listFaceEmbedding: e.value,
                  studentCode: mapPin[e.key], // MSSV from Hive Person.pin
                  // personName: FaceNative record first, then Hive Person name
                  personName: faceNameMap[e.key] ?? mapName[e.key],
                ))
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
    Future<Map<String, dynamic>> checkIn(CheckInOut checkIn,
        {DateTime? sessionStartTime, String? sessionId}) async {
      // null is false, int is minutes late
      try {
        final activeRoomId = await _getActiveRoomIdSafely();
        final normalizedRoomId =
            (checkIn.roomId != null && checkIn.roomId!.trim().isNotEmpty)
                ? checkIn.roomId!.trim()
                : activeRoomId;
        final minutesLate = _isLate(checkIn, sessionStartTime: sessionStartTime);
        final status = minutesLate > 0 ? 'late' : 'on_time';

        final persons = await _hiveService.getAllPersons();
        final studentPerson = _findStudentPerson(persons, checkIn.studentId, checkIn.name, checkIn.pin);

        final resolvedPin = studentPerson?.pin ?? checkIn.pin;
        final resolvedStudentId = studentPerson?.studentId ?? checkIn.studentId;

        final checkInToSave =
            (normalizedRoomId != null && normalizedRoomId.isNotEmpty)
                ? checkIn.copyWith(
                    roomId: normalizedRoomId,
                    minutesLate: minutesLate,
                    status: status,
                    pin: resolvedPin,
                    studentId: resolvedStudentId,
                  )
                : checkIn.copyWith(
                    minutesLate: minutesLate,
                    status: status,
                    pin: resolvedPin,
                    studentId: resolvedStudentId,
                  );

        await _hiveService.saveCheckInOut(checkInToSave);

        // >>> Save PendingEduCheckIn for EDU sync <<<
        final deviceCode = await getDeviceCode();
        final localId =
            '${deviceCode}_${checkInToSave.time.millisecondsSinceEpoch}';

        final pendingEdu = PendingEduCheckIn(
          localId: localId,
          studentId: checkInToSave.studentId,
          sessionId:
              sessionId, // Auto-resolved by backend using roomId + timestamp if null
          roomId: checkInToSave.roomId,
          timestamp: checkInToSave.time,
          deviceId: deviceCode,
          serverUserId: studentPerson?.serverUserId,
          pin: resolvedPin,
          minutesLate: minutesLate,
          status: status,
        );

        await savePendingEduCheckIn(pendingEdu);
        await pushLog(
            'Saved PendingEduCheckIn to local queue: localId=$localId, studentId=${pendingEdu.studentId}, room=${pendingEdu.roomId}, pin=${pendingEdu.pin}, serverUserId=${pendingEdu.serverUserId}');

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

        final persons = await _hiveService.getAllPersons();
        final studentPerson = _findStudentPerson(persons, checkOut.studentId, checkOut.name, checkOut.pin);

        CheckInOut checkInOut = CheckInOut(
          pin: studentPerson?.pin ?? checkOut.pin,
          name: checkOut.name,
          time: checkOut.time,
          isCheckIn: false,
          studentId: studentPerson?.studentId ?? checkOut.studentId,
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
      await _sharedPreferences.put<String>(SharedPrefsKey.activeRoom, roomId);
    }

    @override
    Future<String?> getActiveRoomId() async {
      return _sharedPreferences.get<String>(SharedPrefsKey.activeRoom);
    }

    @override
    Future<void> saveActiveRoomName(String roomName) async {
      await _sharedPreferences.put<String>(
          SharedPrefsKey.activeRoomName, roomName);
    }

    @override
    Future<String?> getActiveRoomName() async {
      return _sharedPreferences.get<String>(SharedPrefsKey.activeRoomName);
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
      // No-op: previously this nulled latestTimePullFaceData to trigger a full
      // server pull on the next sync, which also caused ALL other faces to be
      // re-imported (regression).  Per-user local resets are now handled by
      // addFaceResetSkipPins() + importFaceData(), which preserves the
      // incremental sync watermark intact.
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

            // Verify empId migration actually happened in FaceNative
            if (existingPerson.studentId != student.id) {
              final verifyRecords =
                  await _faceNative.getFaceImageRecordByListEmpId([student.id]);
              if (verifyRecords.isEmpty) {
                // Migration may have failed — retry once
                await pushLog(
                    '[syncStudentsFromServer] empId migration verification failed for '
                    '${existingPerson.studentId} → ${student.id}. Retrying...');
                await _faceNative.updatePerson(
                    existingPerson.studentId, student.name,
                    newId: student.id);
                final retryRecords =
                    await _faceNative.getFaceImageRecordByListEmpId([student.id]);
                if (retryRecords.isEmpty) {
                  await pushLog(
                      '[syncStudentsFromServer] empId migration STILL failed after retry. '
                      'Face data for "${student.name}" may be orphaned under old empId=${existingPerson.studentId}');
                } else {
                  await pushLog(
                      '[syncStudentsFromServer] empId migration succeeded on retry');
                }
              }
            }

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

    @override
    Future<int> purgeInvalidEduCheckIns() async {
      try {
        final count = await _hiveService.purgeInvalidEduCheckIns();
        if (count > 0) {
          await pushLog(
            '[EduSync] Purged $count invalid PendingEduCheckIn items '
            '(studentId=0, no serverUserId, no valid pin)',
          );
        }
        return count;
      } catch (e) {
        await pushLog('Error in purgeInvalidEduCheckIns: $e');
        return 0;
      }
    }

    // --- Pending recovery student ids ---
    @override
    Future<void> addPendingRecoveryStudentIds(List<String> ids) async {
      final current = await getPendingRecoveryStudentIds();
      current.addAll(ids);
      final strList = current.toList();
      _sharedPreferences.put<List<String>>(
          SharedPrefsKey.pendingRecoveryStudentIds, strList);
    }

    @override
    Future<Set<String>> getPendingRecoveryStudentIds() async {
      final strList = _sharedPreferences
              .get<List<String>>(SharedPrefsKey.pendingRecoveryStudentIds) ??
          [];
      return strList.toSet();
    }

    @override
    Future<void> clearPendingRecoveryStudentIds() async {
      _sharedPreferences.clearKey(SharedPrefsKey.pendingRecoveryStudentIds);
    }
  }
