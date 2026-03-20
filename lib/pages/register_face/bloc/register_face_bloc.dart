import 'dart:math';

import 'package:face_native/face_native.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/data/local/hive_service.dart';
import 'package:face_time_keeping/data/local/local_service.dart';

import 'package:face_time_keeping/entities/student.dart';
import 'package:face_time_keeping/entities/person.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'register_face_state.dart';

@Injectable()
class RegisterFaceBloc extends Cubit<RegisterFaceState> {
  RegisterFaceBloc(this._localService, this._hiveService) : super(RegisterFaceState()) {
    _faceNative = FaceNative();
  }

  final LocalService _localService;
  final HiveService _hiveService;
  late final FaceNative _faceNative;

  Future<void> init(Student? student) async {
    try {
      emit(state.copyWith(student: student));
      if (student?.id != null) {
        final isRegistered = await _localService.isRegistered(student!.id);
        List<int> oldImageIds = [];
        if (isRegistered) {
          oldImageIds = await _faceNative.getImageIdsByEmpId(student.id);
        }
        // Chỉ thực sự đã đăng ký khi có ảnh trong native engine.
        // Hive lưu Person cho tất cả học sinh được sync từ server,
        // nên không thể dùng isRegistered (Hive) một mình để kết luận.
        final actuallyRegistered = isRegistered && oldImageIds.isNotEmpty;
        emit(state.copyWith(isRegistered: actuallyRegistered, oldImageIds: oldImageIds));
      }
    } catch (e) {
      await pushLog('Error in init: $e');
    }
  }

  Future<void> insertAddedImageIds(int imageId) async {
    emit(state.copyWith(addedImageIds: [...state.addedImageIds, imageId]));
  }

  Future<void> onLivenessResetStep() async {
    try {
      await _faceNative.removeImages(state.student!.id);
    } catch (e) {
      await pushLog('Error in onLivenessResetStep: $e');
    }
  }

  Future<bool> onLivenessSuccessStep(String? imagePath) async {
    try {
      if (imagePath != null) {
        final imageId = await _faceNative.addImage(
          empId: state.student!.id,
          personName: state.student!.name,
          imageUri: imagePath,
          pin: state.student!.pin,
        );
        if (imageId != -1) {
          await insertAddedImageIds(imageId);
          return true;
        }
        return false;
      }
      return false;
    } catch (e) {
      await pushLog('Error in _onLivenessSuccessStep: $e');
      return false;
    }
  }

  Future<void> removeAddedImageIds() async {
    try {
      await _faceNative.removeImagesByIds(state.addedImageIds);
      emit(state.copyWith(addedImageIds: []));
    } catch (e) {
      await pushLog('Error in removeAddedImageIds: $e');
    }
  }

  Future<void> registerFace() async {
    try {
      if (state.student?.id == null) {
        return;
      }
      emit(state.copyWith(requestStatus: RequestStatus.requesting));
      await _hiveService.savePerson(Person(
        studentId: state.student!.id,
        name: state.student!.name,
        pin: state.student!.pin,
        jobTitle: state.student!.jobTitle,
        updatedTime: DateTime.now(),
      ));
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        message: 'Đăng ký thành công! ',
      ));
    } catch (e) {
      await pushLog('Error in registerFace: $e');
      _faceNative.removeImages(state.student!.id);
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: e.toString(),
      ));
    }
  }

  Future<void> updateFace() async {
    try {
      if (state.student?.id == null) {
        return;
      }
      emit(state.copyWith(requestStatus: RequestStatus.requesting));

      // Remove existing images first
      await _faceNative.removeImagesByIds(state.oldImageIds);
      await _hiveService.updatePersonSynced(state.student!.id, false);
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        message: 'Cập nhật thành công! ',
      ));
    } catch (e) {
      await pushLog('Error in updateFace: $e');
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: e.toString(),
      ));
    }
  }
}
