import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:face_native/face_native.dart';
import 'package:face_native/face_native_method_channel.dart';

import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/location_util.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/data/local/local_service.dart';

import 'package:face_time_keeping/entities/check_in.dart';
import 'package:face_time_keeping/entities/student.dart';
import 'package:face_time_keeping/pages/bloc/app_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';
import 'package:image/image.dart' as img;

import '../../../common/resources/asset_sounds.dart';
import '../../../entities/check_in_out.dart';
import 'checking_state.dart';

@Injectable()
class CheckingBloc extends Cubit<CheckingState> {
  CheckingBloc(this._localService, this._appBloc) : super(CheckingState()) {
    _faceNative = FaceNative();
  }

  final LocalService _localService;
  static AudioPlayer player = AudioPlayer();
  late final FaceNative _faceNative;
  final AppBloc _appBloc;
  late Position _location;
  StreamSubscription? _positionSubscription;

  Future<void> _ensureFaceNativeInitialized() async {
    try {
      final tenantId = await _localService.getTenantId();
      await _faceNative.initObjectBox(tenantId.toString());
      debugPrint('FaceNative reinitialized in CheckingBloc');
    } catch (e) {
      debugPrint('Failed to reinitialize FaceNative: $e');
      if (!isClosed) {
        emit(state.copyWith(
            requestStatus: RequestStatus.failed,
            message: e.toString()));
      }
    }
  }

  Future<void> init() async {
    try {
      if (_appBloc.state.position != null) {
        _location = _appBloc.state.position!;
      } else {
        _location = await LocationUtil.getCurrentPosition();
      }
      _positionSubscription = _appBloc.stream.listen((appState) {
        if (appState.position != null) {
          _location = appState.position!;
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    return super.close();
  }

  Future<void> verify(XFile? file, bool isCheckIn) async {
    if (file == null) {
      return;
    }
    try {
      emit(state.copyWith(requestStatus: RequestStatus.requesting));
      late final FaceRecognitionResponse result;
      if (Platform.isIOS) {
        result = await _faceNative.recognizeFace(imagePath: file.path);
      } else if (Platform.isAndroid) {
        final Uint8List bytes = await file.readAsBytes();
        result = await _faceNative.recognizeFace(imageBytes: bytes);
      } else {
        return;
      }
      if (result.result.personName != 'Not_recognized') {
        final RecognitionResult recognitionResult = result.result;
        if (recognitionResult.spoofResult?.isSpoof ?? false) {
          emit(state.copyWith(
              requestStatus: RequestStatus.failed, message: 'Spoof detected'));
          return;
        }
        final verifyStudent = Student(
          name: recognitionResult.personName,
          pin: recognitionResult.pin,
          id: recognitionResult.studentId,
        );
        emit(state.copyWith(isAllowCapture: false));
        await _checkInLocal(verifyStudent, file);
        await _resetState();
      } else {
        emit(state.copyWith(requestStatus: RequestStatus.failed, message: ''));
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Singleton') ||
          errorMsg.contains('create instance') ||
          errorMsg.contains('KoinApplication')) {
        debugPrint('Koin not initialized in CheckingBloc, reinitializing...');
        await _ensureFaceNativeInitialized();
        await verify(file, isCheckIn);
        return;
      }
      if (!isClosed) {
        emit(state.copyWith(
            requestStatus: RequestStatus.failed, message: errorMsg));
      }
    }
  }

  Future<String> compressImageFromXFile(
    XFile xfile, {
    int targetWidth = 400,
    int quality = 10,
  }) async {
    final String outputPath = "${xfile.path}_compressed.jpg";

    try {
      Uint8List bytes = await xfile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) throw Exception("Không decode được ảnh");

      img.Image resized = img.copyResize(originalImage, width: targetWidth);
      List<int> compressedBytes = img.encodeJpg(resized, quality: quality);

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(compressedBytes);
    } catch (e) {
      debugPrint("Image compression failed: $e");
    }

    return outputPath;
  }

  Future<void> _checkInLocal(Student student, XFile file) async {
    try {
      emit(state.copyWith(checkingStatus: RequestStatus.requesting));
      final compressedImage = await compressImageFromXFile(file);

      final checkIn = CheckInOut(
        pin: student.pin,
        name: student.name,
        time: DateTime.now(),
        isCheckIn: true,
        imagePath: compressedImage,
        studentId: student.id,
        latitude: _location.latitude,
        longitude: _location.longitude,
      );
      final Map<String, dynamic> result = await _localService.checkIn(checkIn);
      if (result['errorMessage'] != null) {
        emit(state.copyWith(
            checkingStatus: RequestStatus.failed,
            checkingMessage: result['errorMessage']));
        return;
      }
      final minutesLate = result['minutesLate'] as int?;
      _playSuccessAudio();
      emit(state.updateCheckin(
          checkIn: CheckIn(
              minutesLate: minutesLate,
              time: checkIn.time,
              pin: checkIn.pin,
              imagePath: checkIn.imagePath ?? '',
              studentName: student.name),
          checkingStatus: RequestStatus.success,
          image: file));
    } catch (e) {
      await pushLog('Error in checkInLocal: $e');
      emit(state.copyWith(
          checkingStatus: RequestStatus.failed, checkingMessage: e.toString()));
    }
  }

  // ============================================================
  // DEPRECATED: Use Student entity instead
  // ============================================================

  // ============================================================
  // DEPRECATED: Use Student entity instead
  // ============================================================

  Future<void> _playSuccessAudio() async {
    try {
      await player.play(AssetSource(AssetSounds.successSound));
      await Future.delayed(const Duration(milliseconds: 600));
    } catch (e) {
      debugPrint('play sound failed!');
    }
  }

  Future<void> setAllowCapture(bool isAllowCapture) async {
    emit(state.copyWith(isAllowCapture: isAllowCapture));
  }

  Future<void> _resetState() async {
    await Future.delayed(const Duration(seconds: 3));
    emit(state.refreshState());
  }
}
