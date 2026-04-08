import 'dart:async';
import 'dart:developer';

import 'package:face_native/face_native.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/utils/extensions/string_extension.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/common/utils/sync_jobs_util.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/local/hive_service.dart';
import 'package:face_time_keeping/data/models/register_user_request.dart';
import 'package:face_time_keeping/data/remote/user_service.dart';
import 'package:face_time_keeping/entities/student.dart' as student_entity;
import 'package:face_time_keeping/entities/person.dart';
import 'package:face_time_keeping/entities/register_student.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../common/api_client/data_state.dart';
import '../../../common/event/event_bus_mixin.dart';
import '../../../pages/widgets/content_widget.dart';
import '../../../di/injection.dart';
import 'student_state.dart';

@Injectable()
class StudentBloc extends Cubit<StudentState> with EventBusMixin {
  StudentBloc(this._userRepository, this._hiveService)
      : super(const StudentState()) {
    registerEventSubscriptions();
  }

  final UserService _userRepository;
  final HiveService _hiveService;
  final FaceNative _faceNative = FaceNative();
  List<student_entity.Student> _savedStudents = [];
  List<student_entity.Student> _savedServerStudents = [];
  List<student_entity.Student> _savedMergedStudents = [];
  List<StreamSubscription> _eventSubscriptions = [];

  @override
  Future<void> close() {
    cancelAllEventSubscriptions();
    return super.close();
  }

  void registerEventSubscriptions() {
    final e1 =
        listenEvent<DidChangeStudentEvent>((e) => _didUpdateStudent(e.student));
    final e2 = listenEvent<SyncStudentEvent>((e) => _onSyncStudentComplete(e));
    _eventSubscriptions.addAll([e1, e2]);
  }

  void cancelAllEventSubscriptions() {
    _eventSubscriptions.forEach((sub) => sub.cancel());
    _eventSubscriptions.clear();
  }

  void init() {
    _fetchStudents();
  }

  void refresh() {
    _fetchStudents();
  }

  Future<void> fetchServerStudents() async {
    try {
      emit(state.copyWith(serverStatus: DataSourceStatus.refreshing));
      final DataState<List<UserInfo>> result =
          await _userRepository.getUsersByRole('student');
      if (result.isSuccess) {
        final records = await _faceNative.getAllImages();
        final faceIds = records.map((e) => e.empId).toSet();

        // Map 3 (most direct): FaceNative.personName → empId
        // pullFaceData stores personName directly in FaceNative from the server
        // response, so this works even when Hive Person has null pin or
        // name == 'Unknown' (created before syncStudentsFromServer ran).
        final Map<String, int> faceNameToEmpId = {
          for (final r in records)
            if (r.personName.isNotEmpty) r.personName: r.empId,
        };

        final localPersons = await _hiveService.getAllPersons();
        // Map 1: studentCode/PIN → Hive studentId (primary bridge)
        final Map<String, int> pinToStudentId = {
          for (final p in localPersons)
            if (p.pin != null && p.pin!.isNotEmpty) p.pin!: p.studentId,
        };
        // Map 2: Hive name → studentId (secondary bridge)
        final Map<String, int> nameToStudentId = {
          for (final p in localPersons)
            if (p.name != null && p.name!.isNotEmpty) p.name!: p.studentId,
        };

        final students = (result.data ?? []).map((u) {
          // Priority 1: studentCode/PIN → Hive.studentId → FaceNative.empId
          final pin = u.studentCode;
          final int? byPin =
              (pin != null && pin.isNotEmpty) ? pinToStudentId[pin] : null;
          bool hasFace = byPin != null && faceIds.contains(byPin);

          // Priority 2: Hive name → studentId → FaceNative.empId
          if (!hasFace) {
            final byName = nameToStudentId[u.fullName];
            hasFace = byName != null && faceIds.contains(byName);
          }

          // Priority 3: directly match server full_name against FaceNative
          // personName — most reliable for server-pulled faces because
          // FaceNative stores personName from the pull response unchanged.
          if (!hasFace) {
            hasFace = faceNameToEmpId.containsKey(u.fullName);
          }

          return student_entity.Student.fromUserJson({
            'id': u.id,
            'full_name': u.fullName,
            'avatar_url': u.avatarUrl,
            'student_code': u.studentCode,
          }).copyWith(hasFace: hasFace);
        }).toList();
        _savedServerStudents = students;
        emit(state.copyWith(
            studentsFromServer: students,
            serverStatus: students.isEmpty
                ? DataSourceStatus.empty
                : DataSourceStatus.success));
      } else {
        emit(state.copyWith(serverStatus: DataSourceStatus.failed));
      }
    } catch (e) {
      await pushLog('Error in fetchServerStudents: $e');
      emit(state.copyWith(serverStatus: DataSourceStatus.failed));
    }
    _emitMergedStudents();
  }

  /// Gộp danh sách local + server, loại trùng (ưu tiên server).
  /// Local-only students = chưa sync lên server (isFromServer = false).
  void _emitMergedStudents() {
    final Map<String, student_entity.Student> merged = {};

    // 1. Thêm server students trước (ưu tiên)
    for (final s in _savedServerStudents) {
      final validPin = (s.pin != null && s.pin!.trim().isNotEmpty) ? s.pin!.trim() : null;
      final key = validPin ?? 'server_${s.id}';
      merged[key] = s;
    }

    // 2. Thêm local students — nếu pin trùng với server thì bỏ qua
    for (final s in _savedStudents) {
      final validPin = (s.pin != null && s.pin!.trim().isNotEmpty) ? s.pin!.trim() : null;
      final key = validPin ?? 'local_${s.id}';
      if (!merged.containsKey(key)) {
        merged[key] = s;
      } else {
        final existing = merged[key]!;
        if (!existing.hasFace && s.hasFace) {
          merged[key] = existing.copyWith(hasFace: true, id: s.id); // Prefer local ID if merging for face
        }
      }
    }

    final mergedList = merged.values.toList();
    _savedMergedStudents = mergedList;
    emit(state.copyWith(mergedStudents: mergedList));
  }

  Future<void> syncData() async {
    await SyncJobsUtil.syncStudentDataNow();
  }

  void _didUpdateStudent(Student? student) {
    if (student == null) return;
    final List<student_entity.Student> newValues =
        List.from(state.students ?? []);
    final index = newValues.indexWhere((element) => element.id == student.id);
    if (index >= 0) {
      newValues[index] = student_entity.Student(
        id: student.id ?? 0,
        pin: null,
        name: student.name ?? '',
      );
      emit(state.copyWith(students: newValues));
    }
  }

  Future<void> _onSyncStudentComplete(SyncStudentEvent event) async {
    if (event.status == 'in_progress') {
      return;
    }
    await _hiveService.refreshPersonBox();
    Future.delayed(const Duration(seconds: 1), () => _fetchStudents());
  }

  Future<void> onRefresh() async {
    emit(state.copyWith(status: DataSourceStatus.refreshing));
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    try {
      final List<Person> result = await _hiveService.getAllPersons();
      final records = await _faceNative.getAllImages();
      final faceIds = records.map((e) => e.empId).toSet();
      
      if (records.isNotEmpty) {
        final Map<int, String> uniqueFaces = {};
        for (var doc in records) {
          uniqueFaces[doc.empId] = doc.personName;
        }
        final faceNames = uniqueFaces.entries
            .map((e) => "${e.value} (ID: ${e.key})")
            .toList();
        await pushLog('[DEBUG] Học sinh có khuôn mặt local (Unique): $faceNames');
      }

      final students = List<student_entity.Student>.from(result.map((e) {
        final student = e.toStudent();
        final hasFaceLocal = faceIds.contains(e.studentId);
        return student.copyWith(hasFace: hasFaceLocal);
      }));
      _savedStudents = students;
      emit(state.copyWith(
          students: students,
          status: students.isEmpty
              ? DataSourceStatus.empty
              : DataSourceStatus.success));
      _emitMergedStudents();
    } catch (e) {
      await pushLog('Error in _fetchStudents: $e');
      emit(state.copyWith(status: DataSourceStatus.failed));
    }
  }

  void onSearch(String? text, {bool isServerTab = false}) {
    if (text?.isEmpty ?? true) {
      if (isServerTab) {
        emit(state.copyWith(studentsFromServer: _savedServerStudents));
      } else {
        emit(state.copyWith(students: _savedStudents));
      }
      // Cập nhật merged khi xóa tìm kiếm
      emit(state.copyWith(mergedStudents: _savedMergedStudents));
      return;
    }
    final textLower = text!.removeVietnameseDiacritics().toLowerCase();
    log('textLower: $textLower');

    if (isServerTab) {
      final results = List<student_entity.Student>.from(_savedServerStudents)
          .where((element) => element.name
              .removeVietnameseDiacritics()
              .contains(text.removeVietnameseDiacritics()))
          .toList();
      emit(state.copyWith(studentsFromServer: results));
    } else {
      final results = List<student_entity.Student>.from(_savedStudents)
          .where((element) => element.name
              .removeVietnameseDiacritics()
              .contains(text.removeVietnameseDiacritics()))
          .toList();
      emit(state.copyWith(students: results));
    }
    // Search trong merged list
    final mergedResults =
        List<student_entity.Student>.from(_savedMergedStudents)
            .where((element) => element.name
                .removeVietnameseDiacritics()
                .contains(text.removeVietnameseDiacritics()))
            .toList();
    emit(state.copyWith(mergedStudents: mergedResults));
  }

  Future<bool> onRegisterStudent(
      RegisterStudent registerStudent, bool hasServerConfig) async {
    if (hasServerConfig) {
      return (await onRegisterStudentToServer(registerStudent));
    } else {
      return (await onRegisterStudentLocal(registerStudent));
    }
  }

  Future<bool> onRegisterStudentToServer(
      RegisterStudent registerStudent) async {
    final DataState<student_entity.Student> result =
        await _userRepository.registerStudent(registerStudent);
    if (result.isSuccess) {
      final List<student_entity.Student> newValues =
          List.from(state.students ?? []);
      newValues.add(result.data!);
      final registerStudentData = RegisterStudent(
        studentId: result.data?.id,
        studentName: result.data!.name,
        jobPosition: result.data!.jobTitle,
        pin: result.data?.pin ?? '',
        avatar: result.data?.avatar,
        serverUserId: result.data?.serverUserId, // pass UUID for EDU sync
      );
      await onRegisterStudentLocal(registerStudentData);
      emit(state.copyWith(
          studentsFromServer: newValues,
          serverStatus: DataSourceStatus.success));
      return true;
    } else {
      emit(state.copyWith(
          serverStatus: DataSourceStatus.failed,
          error: result.error,
          students: state.students));
    }
    return false;
  }

  Future<bool> onRegisterStudentLocal(RegisterStudent registerStudent) async {
    try {
      final pin = registerStudent.pin.trim();
      if (pin.isNotEmpty) {
        final existingStudents = await _hiveService.getAllPersons();
        final duplicatePin = existingStudents.any(
          (person) => person.pin?.trim() == pin,
        );

        if (duplicatePin) {
          emit(state.copyWith(
            status: DataSourceStatus.failed,
            error: 'Mã PIN "$pin" đã tồn tại. Vui lòng sử dụng mã PIN khác.',
            students: state.students,
          ));
          return false;
        }
      }

      await _hiveService.savePerson(Person(
        studentId: registerStudent.studentId ??
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
        pin: registerStudent.pin,
        name: registerStudent.studentName,
        jobTitle: registerStudent.jobPosition,
        avatar: registerStudent.avatar,
        serverUserId: registerStudent.serverUserId,
        updatedTime: DateTime.now(),
      ));
      _fetchStudents();
      return true;
    } catch (e) {
      await pushLog('Error in onRegisterStudent: $e');
      emit(state.copyWith(
          status: DataSourceStatus.failed,
          error: 'Lỗi khi đăng ký học sinh: $e',
          students: state.students));
    }
    return false;
  }

  Future<List<int>> _findLocalStudentIds(student_entity.Student student) async {
    final localPersons = await _hiveService.getAllPersons();
    final sName = student.name.trim().toLowerCase();
    final sPin = student.pin?.trim().toLowerCase() ?? '';

    final localIds = <int>{student.id};
    for (final p in localPersons) {
      final pPin = p.pin?.trim().toLowerCase() ?? '';
      if (sPin.isNotEmpty && pPin == sPin) {
        localIds.add(p.studentId);
      } else if (p.name?.trim().toLowerCase() == sName) {
        if (sPin.isEmpty && pPin.isEmpty) {
          localIds.add(p.studentId);
        }
      }
    }
    return localIds.toList();
  }

  Future<bool> onRemoveStudent(student_entity.Student student) async {
    bool serverDeleted = false;
    final localService = getIt<LocalService>();
    final syncLockToken = await localService.acquireFaceSyncLock();
    if (syncLockToken == null) {
      emit(state.copyWith(
          status: DataSourceStatus.failed,
          error: 'Hệ thống đang đồng bộ dữ liệu tĩnh, vui lòng thử lại sau.',
          students: state.students));
      return false;
    }
    try {
      await pushLog(
          '[onRemoveStudent] Start: id=${student.id}, name="${student.name}", pin="${student.pin}", serverUserId=${student.serverUserId}');

      // 1. Delete on server if there's a serverUserId
      if (student.serverUserId != null && student.serverUserId!.isNotEmpty) {
        final res = await _userRepository.deleteUser(student.serverUserId!);
        if (!res.isSuccess) {
          emit(state.copyWith(
              status: DataSourceStatus.failed,
              error: res.error ?? 'Lỗi khi xóa học sinh trên server',
              students: state.students));
          return false;
        }
        serverDeleted = true;
        await pushLog('[onRemoveStudent] Server delete OK');
      }

      // 2. Delete locally — Hive + native face
      try {
        final localIds = await _findLocalStudentIds(student);
        for (final id in localIds) {
          await _hiveService.deletePerson(id);
        }

        final records = await _faceNative.getAllImages();
        final targetEmpIds = Set<int>.from(localIds);
        final sName = student.name.trim().toLowerCase();

        for (final r in records) {
          if (targetEmpIds.contains(r.empId)) continue;
          
          final pName = r.personName.trim().toLowerCase();
          if (pName.isNotEmpty && pName == sName) {
            final personForRecord = (await _hiveService.getAllPersons())
                .cast<Person?>()
                .firstWhere(
                  (p) => p!.studentId == r.empId,
                  orElse: () => null,
                );
            if (personForRecord == null) {
              targetEmpIds.add(r.empId);
            }
          }
        }

        await pushLog(
            '[onRemoveStudent] Deleting native empIds: ${targetEmpIds.join(', ')}');
        for (final empId in targetEmpIds) {
          await _faceNative.removeImages(empId);
        }
      } catch (localErr) {
        await pushLog(
            '[onRemoveStudent] LOCAL DELETE FAILED after server=${serverDeleted ? "deleted" : "skipped"}: $localErr');
        if (serverDeleted) {
          emit(state.copyWith(
              status: DataSourceStatus.failed,
              error:
                  'Đã xóa trên server nhưng xóa local thất bại. Vui lòng khởi động lại ứng dụng.',
              students: state.students));
          return false;
        }
        rethrow;
      }

      // 3. Refresh lists
      await _fetchStudents();
      if (student.isFromServer || student.serverUserId != null) {
        await fetchServerStudents();
      }
      await pushLog('[onRemoveStudent] Done OK');
      return true;
    } catch (e) {
      await pushLog('[onRemoveStudent] Error: $e');
      emit(state.copyWith(
          status: DataSourceStatus.failed,
          error: 'Lỗi khi xóa học sinh: $e',
          students: state.students));
      return false;
    } finally {
      localService.releaseFaceSyncLock(syncLockToken);
    }
  }

  Future<bool> onResetFace(student_entity.Student student,
      {bool hasServerConfig = true}) async {
    final studentId = student.id;
    bool serverDeleted = false;
    final localService = getIt<LocalService>();
    final syncLockToken = await localService.acquireFaceSyncLock();
    if (syncLockToken == null) {
      emit(state.copyWith(
          status: DataSourceStatus.failed,
          error: 'Hệ thống đang đồng bộ dữ liệu tĩnh, vui lòng thử lại sau.',
          students: state.students));
      return false;
    }

    try {
      await pushLog(
          '[onResetFace] Start: id=$studentId, name="${student.name}", pin="${student.pin}", serverConfig=$hasServerConfig');

      // 1. Delete on server
      if (hasServerConfig) {
        // Warning: This passes the integer id. To properly fix it on V1, it might require UUID, but preserving behavior.
        final res = await _userRepository.deleteFace(studentId);
        if (!res.isSuccess) {
          emit(state.copyWith(
              status: DataSourceStatus.failed,
              error: res.error ?? 'Lỗi khi xóa khuôn mặt trên server',
              students: state.students));
          return false;
        }
        serverDeleted = true;
        await pushLog('[onResetFace] Server delete OK');
      }

      // 2. Delete locally — match by empId, name, AND pin in FaceNative
      Set<int> targetEmpIds = {};
      try {
        final localIds = await _findLocalStudentIds(student);
        targetEmpIds = Set<int>.from(localIds);

        final records = await _faceNative.getAllImages();
        final sName = student.name.trim().toLowerCase();
        final sPin = (student.pin ?? '').trim().toLowerCase();

        for (final r in records) {
          if (targetEmpIds.contains(r.empId)) continue;

          // Match by personName
          final pName = r.personName.trim().toLowerCase();
          if (pName.isNotEmpty && pName == sName) {
            targetEmpIds.add(r.empId);
            continue;
          }

          // Match by pin stored in the FaceNative record
          final rPin = r.pin.trim().toLowerCase();
          if (sPin.isNotEmpty && rPin.isNotEmpty && rPin == sPin) {
            targetEmpIds.add(r.empId);
          }
        }

        await pushLog(
            '[onResetFace] Deleting native empIds: ${targetEmpIds.join(', ')}');

        for (final empIdToDelete in targetEmpIds) {
          await _faceNative.removeImages(empIdToDelete);
          try {
            await _hiveService.deletePerson(empIdToDelete);
            localService.clearProcessedKeyForStudent(empIdToDelete);
          } catch (_) {
            // Ignore if person id doesn't exactly match hive key, or isn't in hive
          }
        }
      } catch (localErr) {
        await pushLog(
            '[onResetFace] LOCAL DELETE FAILED after server=${serverDeleted ? "deleted" : "skipped"}: $localErr');
        if (serverDeleted) {
          emit(state.copyWith(
              status: DataSourceStatus.failed,
              error:
                  'Đã xóa trên server nhưng xóa local thất bại. Vui lòng khởi động lại ứng dụng.',
              students: state.students));
          return false;
        }
        rethrow;
      }

      // 3. Refresh lists to update hasFace indicator
      await _fetchStudents();
      await fetchServerStudents();

      // If deleting locally only (server copy preserved), add this student
      // to the pending recovery list so next pullFaceData cycle receives it explicitly.
      // This avoids rolling back the global watermark by 36h which would redownload all recent changes.
      if (!hasServerConfig) {
        final idsToRecover = targetEmpIds.map((id) => id.toString()).toList();
        await localService.addPendingRecoveryStudentIds(idsToRecover);
        await pushLog(
            '[onResetFace] Added students $idsToRecover to explicitly pending recovery list '
            'so next sync can restore "${student.name}" from server without altering watermark');
      }

      // Force UI update: The face is now removed locally
      final updatedStudent = student.copyWith(hasFace: false);
      await onUpdateStudentInList(updatedStudent);

      await pushLog('[onResetFace] Done OK');
      return true;
    } finally {
      localService.releaseFaceSyncLock(syncLockToken);
    }
  }

  Future<void> onUpdateStudentInList(student_entity.Student student,
      {bool isUpdatePin = false}) async {
    final pin = student.pin?.trim() ?? '';
    if (pin.isNotEmpty) {
      final existingStudents = await _hiveService.getAllPersons();
      final duplicatePin =
          existingStudents.any((person) => person.pin?.trim() == pin);

      if (duplicatePin && isUpdatePin) {
        emit(state.copyWith(
          status: DataSourceStatus.failed,
          error: 'Mã PIN "$pin" đã tồn tại. Vui lòng sử dụng mã PIN khác.',
          students: state.students,
        ));
        return;
      }
    }

    final existingPerson = await _hiveService.getPerson(student.id);

    if (existingPerson != null) {
      await _hiveService.updatePerson(existingPerson.copyWith(
        name: student.name,
        pin: student.pin,
        jobTitle: student.jobTitle,
        hasLocalEmbedding: student.hasFace,
      ));
    } else {
      await _hiveService.updatePerson(student.toPerson());
    }

    await _faceNative.updatePerson(student.id, student.name);
    final List<student_entity.Student> newValues =
        List.from(state.students ?? []);
    final index = newValues.indexWhere((element) => element.id == student.id);
    if (index >= 0) {
      newValues[index] = student;
      emit(state.copyWith(
          students: newValues, status: DataSourceStatus.success));
    }
  }

  Future<void> debugToggleFaceFlag(student_entity.Student student) async {
    final newStudent = student.copyWith(hasFace: !student.hasFace);
    await pushLog('[DEBUG] Toggling face flag for ${student.name} to ${newStudent.hasFace}');
    await onUpdateStudentInList(newStudent);
  }
}
