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
  RegisterFaceBloc(this._localService, this._hiveService)
      : super(RegisterFaceState()) {
    _faceNative = FaceNative();
  }

  final LocalService _localService;
  final HiveService _hiveService;
  late final FaceNative _faceNative;

  Future<void> init(Student? student) async {
    try {
      emit(state.copyWith(student: student));
      if (student == null) return;

      // Students from server have id = UUID.hashCode (unstable), but Hive stores
      // Person with studentId = the real backend integer PK.
      // Use pin (MSSV) as the stable bridge to find the correct local Person.
      int effectiveStudentId = student.id;
      if (student.pin != null && student.pin!.isNotEmpty) {
        final personByPin = await _hiveService.getPersonByPin(student.pin!);
        if (personByPin != null) {
          effectiveStudentId = personByPin.studentId;
        }
      }

      // Fallback: if Hive lookup didn't resolve, check FaceNative records by
      // personName. This handles the case where pullFaceData stored embeddings
      // in FaceNative but Hive Person was not yet created or had a mismatched pin.
      if (effectiveStudentId == student.id) {
        final allRecords = await _faceNative.getAllImages();
        try {
          final match =
              allRecords.firstWhere((r) => r.personName == student.name);
          effectiveStudentId = match.studentId;
        } catch (_) {
          // ignore error — just means no FaceNative record found by name
        }
      }

      final isRegistered = await _localService.isRegistered(effectiveStudentId);
      List<int> oldImageIds = [];
      if (isRegistered) {
        oldImageIds =
            await _faceNative.getImageIdsByStudentId(effectiveStudentId);
      }
      // Chỉ thực sự đã đăng ký khi có ảnh trong native engine.
      // isRegistered (Hive) có thể true cho cả học sinh chưa chụp ảnh (sync từ server),
      // nên phải kiểm tra thêm oldImageIds.
      final actuallyRegistered = isRegistered && oldImageIds.isNotEmpty;

      // Also check FaceNative directly for faces pulled from server
      // (these may exist in FaceNative but not be reflected in Hive's isRegistered).
      final hasFaceInNative = oldImageIds.isNotEmpty ||
          (await _faceNative.getImageIdsByStudentId(effectiveStudentId))
              .isNotEmpty;
      final finalImageIds = oldImageIds.isNotEmpty
          ? oldImageIds
          : await _faceNative.getImageIdsByStudentId(effectiveStudentId);

      // Update student with the correct local id so registerFace/updateFace use it
      final correctedStudent = effectiveStudentId != student.id
          ? student.copyWith(id: effectiveStudentId)
          : student;

      emit(state.copyWith(
        student: correctedStudent,
        isRegistered: actuallyRegistered || hasFaceInNative,
        oldImageIds: finalImageIds,
      ));
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
          studentId: state.student!.id,
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
