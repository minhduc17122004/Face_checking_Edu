import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:face_native/face_native.dart';
import 'package:face_native/face_native_method_channel.dart';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/attendance_checkin_service.dart';
import 'package:face_time_keeping/entities/edu_check_in.dart';
import 'package:face_time_keeping/entities/pending_edu_check_in.dart';
import 'package:face_time_keeping/pages/bloc/app_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:injectable/injectable.dart';

import 'edu_checking_state.dart';

@Injectable()
class EduCheckingBloc extends Cubit<EduCheckingState> {
  EduCheckingBloc(
    this._localService,
    this._checkinService,
    this._appBloc,
  ) : super(const EduCheckingState()) {
    _faceNative = FaceNative();
  }

  final LocalService _localService;
  final AttendanceCheckinService _checkinService;
  final AppBloc _appBloc;

  late final FaceNative _faceNative;
  late Position _location;
  StreamSubscription? _positionSubscription;
  Timer? _pollingTimer;
  String? _currentSessionId;

  static const int _maxRetryCount = 5;

  // ═══════════════════════════════════════════════════════════════
  // Initialisation
  // ═══════════════════════════════════════════════════════════════

  Future<void> init(String sessionId) async {
    _currentSessionId = sessionId;
    try {
      // Location
      if (_appBloc.state.position != null) {
        _location = _appBloc.state.position!;
      } else {
        _location = await _getLocation();
      }
      _positionSubscription = _appBloc.stream.listen((s) {
        if (s.position != null) _location = s.position!;
      });

      // FaceNative
      await _ensureFaceNativeInitialized();

      // Load initial session data
      await _loadSessionData(sessionId);

      // Start polling every 5 s
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _loadSessionData(sessionId);
      });

      // Retry any pending offline records
      await syncPendingCheckIns();
    } catch (e) {
      await pushLog('Error in EduCheckingBloc.init: $e');
      rethrow;
    }
  }

  Future<Position> _getLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
    } catch (_) {
      return Position(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }

  Future<void> _ensureFaceNativeInitialized() async {
    try {
      final tenantId = await _localService.getTenantId();
      await _faceNative.initObjectBox(tenantId.toString());
    } catch (e) {
      debugPrint('Failed to reinitialize FaceNative in EduCheckingBloc: $e');
    }
  }

  Future<void> _loadSessionData(String sessionId) async {
    final records = await _checkinService.getSessionCheckins(sessionId);
    if (records.isSuccess && records.data != null) {
      if (!isClosed) {
        emit(state.copyWith(sessionRecords: records.data));
      }
    }
    final summary = await _checkinService.getSessionSummary(sessionId);
    if (summary.isSuccess && summary.data != null) {
      if (!isClosed) {
        emit(state.copyWith(summary: summary.data));
      }
    }
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    _positionSubscription?.cancel();
    return super.close();
  }

  // ═══════════════════════════════════════════════════════════════
  // Face verification + hybrid check-in
  // ═══════════════════════════════════════════════════════════════

  Future<void> verify(XFile? file) async {
    if (file == null || _currentSessionId == null) return;

    try {
      emit(state.copyWith(
        faceStatus: RequestStatus.requesting,
        isAllowCapture: false,
        clearError: true,
      ));

      late final FaceRecognitionResponse result;
      if (Platform.isIOS) {
        result = await _faceNative.recognizeFace(imagePath: file.path);
      } else if (Platform.isAndroid) {
        final Uint8List bytes = await file.readAsBytes();
        result = await _faceNative.recognizeFace(imageBytes: bytes);
      } else {
        return;
      }

      if (result.result.personName == 'Not_recognized') {
        emit(state.copyWith(
          faceStatus: RequestStatus.failed,
          isAllowCapture: true,
        ));
        return;
      }

      if (result.result.spoofResult?.isSpoof ?? false) {
        emit(state.copyWith(
          faceStatus: RequestStatus.failed,
          errorMessage: 'Phát hiện giả mạo khuôn mặt',
          isAllowCapture: true,
        ));
        return;
      }

      emit(state.copyWith(faceStatus: RequestStatus.success));

      final recognitionResult = result.result;
      final studentId = recognitionResult.studentId;
      final studentName = recognitionResult.personName;
      final compressedPath = await _compressImage(file);

      await _hybridCheckIn(
        sessionId: _currentSessionId!,
        studentId: studentId,
        studentName: studentName,
        imagePath: compressedPath,
      );
    } catch (e) {
      final msg = e.toString();
      // Koin / ObjectBox not initialized → reinit and retry
      if (msg.contains('Singleton') ||
          msg.contains('create instance') ||
          msg.contains('KoinApplication')) {
        await _ensureFaceNativeInitialized();
        await verify(file);
        return;
      }
      if (!isClosed) {
        emit(state.copyWith(
          faceStatus: RequestStatus.failed,
          errorMessage: msg,
          isAllowCapture: true,
        ));
      }
    }
  }

  /// Online-first: try API → on failure save to Hive queue
  Future<void> _hybridCheckIn({
    required String sessionId,
    required int studentId,
    required String studentName,
    String? imagePath,
  }) async {
    if (isClosed) return;
    emit(state.copyWith(checkinStatus: RequestStatus.requesting));

    try {
      final apiResult = await _checkinService.manualCheckin(
        sessionId: sessionId,
        studentId: studentId,
        checkinTime: DateTime.now(),
        deviceId: await _localService.getDeviceCode(),
      );

      if (apiResult.isSuccess && apiResult.data != null) {
        final data = apiResult.data!;
        final checkIn = EduCheckIn(
          studentName: studentName,
          studentId: studentId,
          checkinTime: data.checkinTime,
          status: data.status,
          minutesDiff: data.minutesDiff,
          message: data.message,
          imagePath: imagePath,
        );
        if (!isClosed) {
          emit(state.copyWith(
            checkinStatus: RequestStatus.success,
            lastCheckIn: checkIn,
            isOfflineMode: false,
          ));
        }
        // Refresh immediately after successful check-in
        await _loadSessionData(sessionId);
      } else {
        // API returned an error — fallback to offline queue
        await _saveToOfflineQueue(
          sessionId: sessionId,
          studentId: studentId,
          studentName: studentName,
          imagePath: imagePath,
        );
      }
    } catch (_) {
      // Network error — save to offline queue
      await _saveToOfflineQueue(
        sessionId: sessionId,
        studentId: studentId,
        studentName: studentName,
        imagePath: imagePath,
      );
    }

    await _resetCapture();
  }

  Future<void> _saveToOfflineQueue({
    required String sessionId,
    required int studentId,
    required String studentName,
    String? imagePath,
  }) async {
    final pending = PendingEduCheckIn(
      localId: _uniqueId(),
      studentId: studentId,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      imagePath: imagePath,
      latitude: _location.latitude,
      longitude: _location.longitude,
      studentName: studentName,
    );
    await _localService.savePendingEduCheckIn(pending);
    if (!isClosed) {
      emit(state.copyWith(
        checkinStatus: RequestStatus.success,
        isOfflineMode: true,
        hasPendingSync: true,
        lastCheckIn: EduCheckIn(
          studentName: studentName,
          studentId: studentId,
          checkinTime: pending.timestamp,
          status: 'pending',
          message: 'Đã lưu, sẽ đồng bộ khi có mạng',
          imagePath: imagePath,
        ),
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Background sync retry
  // ═══════════════════════════════════════════════════════════════

  Future<void> syncPendingCheckIns() async {
    final pending = await _localService.getPendingEduCheckIns();
    if (pending.isEmpty) {
      if (!isClosed) emit(state.copyWith(hasPendingSync: false));
      return;
    }
    if (!isClosed) emit(state.copyWith(hasPendingSync: true));

    for (final item in pending) {
      if (item.retryCount >= _maxRetryCount) continue;
      if (item.sessionId == null) continue;

      try {
        final result = await _checkinService.manualCheckin(
          sessionId: item.sessionId!,
          studentId: item.studentId,
          checkinTime: item.timestamp,
          deviceId: await _localService.getDeviceCode(),
        );

        if (result.isSuccess) {
          await _localService.markEduCheckInSynced(item.localId);
        } else {
          await _localService.incrementEduRetryCount(item.localId);
        }
      } catch (_) {
        await _localService.incrementEduRetryCount(item.localId);
      }
    }

    // Clean up synced records
    await _localService.clearSyncedEduCheckIns();

    final remaining = await _localService.getPendingEduCheckIns();
    if (!isClosed) {
      emit(state.copyWith(hasPendingSync: remaining.isNotEmpty));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════

  Future<void> setAllowCapture(bool value) async {
    if (!isClosed) emit(state.copyWith(isAllowCapture: value));
  }

  Future<void> _resetCapture() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!isClosed) emit(state.refreshCapture());
  }

  /// Generates a simple unique string using timestamp + counter.
  static int _idCounter = 0;
  static String _uniqueId() {
    _idCounter++;
    return '${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  Future<String> _compressImage(XFile xfile, {int width = 400, int quality = 10}) async {
    final outputPath = '${xfile.path}_compressed.jpg';
    try {
      final bytes = await xfile.readAsBytes();
      final compressedBytes = await compute(_compressImageTask, {
        'bytes': bytes,
        'width': width,
        'quality': quality,
      });
      if (compressedBytes == null) return xfile.path;
      final outFile = File(outputPath);
      await outFile.writeAsBytes(compressedBytes);
    } catch (e) {
      debugPrint('Image compression failed: $e');
      return xfile.path;
    }
    return outputPath;
  }
}

List<int>? _compressImageTask(Map<String, dynamic> params) {
  try {
    final Uint8List bytes = params['bytes'];
    final int width = params['width'];
    final int quality = params['quality'];
    
    final img.Image? original = img.decodeImage(bytes);
    if (original == null) return null;
    final img.Image resized = img.copyResize(original, width: width);
    return img.encodeJpg(resized, quality: quality);
  } catch (e) {
    return null;
  }
}
