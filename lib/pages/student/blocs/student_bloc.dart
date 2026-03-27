import 'dart:async';
import 'dart:developer';

import 'package:face_native/face_native.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/utils/extensions/string_extension.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/common/utils/sync_jobs_util.dart';
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
    final e2 =
        listenEvent<SyncStudentEvent>((e) => _onSyncStudentComplete(e));
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
        final students = (result.data ?? [])
            .map((u) => student_entity.Student.fromUserJson({
                  'id': u.id,
                  'full_name': u.fullName,
                  'avatar_url': u.avatarUrl,
                  'student_code': u.studentCode,
                }))
            .toList();
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
      final key = s.pin ?? 'server_${s.id}';
      merged[key] = s; // isFromServer = true đã set sẵn trong fromUserJson
    }

    // 2. Thêm local students — nếu pin trùng với server thì bỏ qua
    for (final s in _savedStudents) {
      final key = s.pin ?? 'local_${s.id}';
      if (!merged.containsKey(key)) {
        merged[key] = s; // isFromServer = false (default)
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
    final List<student_entity.Student> newValues = List.from(state.students ?? []);
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
      final students = List<student_entity.Student>.from(result.map((e) => e.toStudent()));
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
    final mergedResults = List<student_entity.Student>.from(_savedMergedStudents)
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
      final List<student_entity.Student> newValues = List.from(state.students ?? []);
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

  Future<bool> onRegisterStudentLocal(
      RegisterStudent registerStudent) async {
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
            DateTime.now().millisecondsSinceEpoch ~/
                1000,
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

  Future<bool> onRemoveStudent(int? studentId) async {
    if (studentId == null) return false;
    try {
      await _hiveService.deletePerson(studentId);
      _faceNative.removeImages(studentId);
      await _fetchStudents();
      return true;
    } catch (e) {
      await pushLog('Error in onRemoveStudent: $e');
      emit(state.copyWith(
          status: DataSourceStatus.failed,
          error: 'Lỗi khi xóa học sinh: $e',
          students: state.students));
      return false;
    }
  }

  Future<bool> onResetFace(int? studentId) {
    if (studentId == null) return Future.value(false);
    return _faceNative.removeImages(studentId);
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

    await _hiveService.updatePerson(student.toPerson());
    await _faceNative.updatePerson(student.id, student.name);
    final List<student_entity.Student> newValues = List.from(state.students ?? []);
    final index = newValues.indexWhere((element) => element.id == student.id);
    if (index >= 0) {
      newValues[index] = student;
      emit(state.copyWith(
          students: newValues, status: DataSourceStatus.success));
    }
  }
}
