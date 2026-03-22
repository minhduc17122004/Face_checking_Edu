# Phase 10: Flutter Frontend Integration — Implementation Report

**Date:** 2026-03-22
**Revision:** Phase 10 — Flutter Frontend Integration with Phase 8/9 Backend
**Status:** Completed

---

## 1. Tổng quan

Phase 10 đồng bộ Flutter frontend với backend Phase 8/9, bao gồm các entity models (Department, Room, TimeSlot, Course, Schedule, Session), services, Cubits, và UI pages mới. Tất cả BLoC/Cubit state đều sử dụng **manual state classes** với `RequestStatus` enum (không dùng Freezed) để match pattern hiện tại của dự án.

---

## 2. Thay đổi quan trọng: BLoC Pattern

### 2.1 Mẫu State/Cubit được sử dụng

Tất cả BLoC/Cubit sử dụng **manual state classes** (không dùng Freezed) giống như `LoginState`/`LoginBloc`:

```dart
// State class — giống LoginState
class DepartmentState {
  final RequestStatus requestStatus;
  final List<Department> departments;
  final String? message;
  final Department? selectedDepartment;

  DepartmentState({
    this.requestStatus = RequestStatus.initial,
    this.departments = const [],
    this.message,
    this.selectedDepartment,
  });

  DepartmentState copyWith({...}) {...}
}

// Cubit — giống LoginBloc
@injectable
class DepartmentBloc extends Cubit<DepartmentState> {
  DepartmentBloc(this._departmentService) : super(DepartmentState());

  final DepartmentService _departmentService;

  Future<void> loadDepartments() async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _departmentService.getDepartments();
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        departments: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error,
      ));
    }
  }
}
```

### 2.2 Các file đã được viết lại

| File | Thay đổi |
|------|----------|
| `department_bloc.dart` | Viết lại hoàn toàn — manual state, Cubit, methods thay vì events |
| `department_state.dart` | Viết lại hoàn toàn — manual class với `copyWith` |
| `room_bloc.dart` | Viết lại hoàn toàn — manual state, Cubit, methods |
| `room_state.dart` | Viết lại hoàn toàn — manual class với `copyWith` |
| `course_bloc.dart` | Viết lại hoàn toàn — thêm `updateCourse()` method |
| `course_state.dart` | Viết lại hoàn toàn — manual class với `copyWith` |
| `schedule_bloc.dart` | Viết lại hoàn toàn — thêm `updateSchedule()` method |
| `schedule_state.dart` | Viết lại hoàn toàn — manual class với `copyWith` |
| `session_bloc.dart` | Viết lại hoàn toàn — thêm `generateDailySessions()` |
| `session_state.dart` | Viết lại hoàn toàn — manual class với `copyWith` |
| `teacher_bloc.dart` | Viết lại hoàn toàn — manual state, Cubit |
| `teacher_state.dart` | Viết lại hoàn toàn — manual class với `copyWith` |

**Đã xóa:** `schedule_event.dart`, `teacher_event.dart` (events được thay bằng methods trên Cubit)

---

## 3. Backend Adjustments

### 3.1 Course Update Endpoint — `PUT /api/v1/courses/{id}`

**Thêm:**
- `CourseUpdate` schema với các trường optional
- `update_course` method trong `CourseService` với validation department/room
- `PUT /api/v1/courses/{id}` endpoint

### 3.2 Schedule Update Endpoint — `PUT /api/v1/schedules/{id}`

**Thêm:**
- `ScheduleUpdate` schema với optional `day_of_week`, `time_slot_id`
- `update()` method trong `ScheduleRepository`
- `PUT /api/v1/schedules/{id}` endpoint

### 3.3 Course Response Enrichment

**Thêm:**
- `instructor_name`, `department_name`, `room_name`, `enrolled_count` vào `CourseOut` schema
- Computed properties trong `Course` model
- Eager-loading trong `CourseRepository` (dùng `joinedload`)

### 3.4 Session Response — `course_name`

**Thêm:**
- `course_name` vào `SessionOut` schema
- Cập nhật `_session_out()` helper trong `sessions.py` router
- Eager-load `Session.course` trong `SessionRepository.list()`

### 3.5 SessionSummary Field Mapping

**Cập nhật `SessionSummary` entity (Flutter):**
- `totalEnrolled` ← `total_students`
- `presentCount` ← `present`
- `absentCount` ← `absent`
- `lateCount` ← `late`
- `attendanceRate` ← `attendance_rate`

---

## 4. Flutter Service Updates

### 4.1 `lib/data/remote/course_service.dart`
- Thêm `updateCourse()` — PUT request đến `/api/v1/courses/{id}`

### 4.2 `lib/data/remote/schedule_service.dart`
- Thêm `updateSchedule()` — PUT request đến `/api/v1/schedules/{id}`

### 4.3 `lib/pages/session/session_detail_page.dart`
- Sửa navigation: `{'sessionId': ...}` → `CheckingArgs(isCheckIn: true, sessionId: ...)`

---

## 5. Files Structure

### 5.1 Entities (không thay đổi pattern)
```
lib/entities/
├── department.dart      # id, code, name, description, teacherCount
├── room.dart            # id, code, name, building, floor, capacity
├── time_slot.dart        # id, periodNumber, startTime, endTime + TimeSlotConfig
├── course.dart          # id, courseName, subject, courseCode, AttendanceMode...
├── schedule.dart        # id, courseId, dayOfWeek, timeSlotId, dayName
├── session.dart         # id, courseId, status, SessionStatus, SessionSummary
└── course_student.dart  # CourseStudent + Teacher
```

### 5.2 Services (không thay đổi pattern)
```
lib/data/remote/
├── department_service.dart  # getDepartments, create, update, delete
├── room_service.dart       # getRooms, create, update, delete
├── course_service.dart    # CRUD + updateCourse, assignRoom, enroll/unenroll
├── schedule_service.dart  # CRUD + updateSchedule, getTimeSlots
├── session_service.dart   # CRUD + activate, close, summary, generate-daily
└── teacher_service.dart   # getTeachers, assignDepartment, removeDepartment
```

### 5.3 BLoCs/Cubits (manual state, Cubit pattern)
```
lib/pages/
├── department/bloc/
│   ├── department_bloc.dart  # Cubit với methods
│   └── department_state.dart
├── room/bloc/
│   ├── room_bloc.dart
│   └── room_state.dart
├── course/bloc/
│   ├── course_bloc.dart
│   └── course_state.dart
├── schedule/bloc/
│   ├── schedule_bloc.dart
│   └── schedule_state.dart
├── session/bloc/
│   ├── session_bloc.dart
│   └── session_state.dart
└── teacher/bloc/
    ├── teacher_bloc.dart
    └── teacher_state.dart
```

---

## 6. API Endpoints

| Method | Endpoint | Mô tả |
|--------|----------|--------|
| GET | `/api/v1/departments` | Liệt kê departments |
| POST | `/api/v1/departments` | Tạo department |
| PUT | `/api/v1/departments/{id}` | Cập nhật department |
| DELETE | `/api/v1/departments/{id}` | Xóa department |
| GET | `/api/v1/rooms` | Liệt kê rooms |
| POST | `/api/v1/rooms` | Tạo room |
| PUT | `/api/v1/rooms/{id}` | Cập nhật room |
| DELETE | `/api/v1/rooms/{id}` | Xóa room |
| GET | `/api/v1/time-slots` | Liệt kê time slots |
| POST | `/api/v1/time-slots` | Tạo time slot |
| GET | `/api/v1/courses` | Liệt kê courses |
| POST | `/api/v1/courses` | Tạo course |
| GET | `/api/v1/courses/{id}` | Chi tiết course |
| PUT | `/api/v1/courses/{id}` | Cập nhật course |
| DELETE | `/api/v1/courses/{id}` | Xóa course |
| PUT | `/api/v1/courses/{id}/assign-room` | Gán room cho course |
| GET | `/api/v1/courses/{id}/students` | Danh sách sinh viên |
| POST | `/api/v1/courses/{id}/students/{studentId}` | Enroll sinh viên |
| DELETE | `/api/v1/courses/{id}/students/{studentId}` | Unenroll sinh viên |
| GET | `/api/v1/schedules` | Liệt kê schedules |
| POST | `/api/v1/schedules` | Tạo schedule |
| PUT | `/api/v1/schedules/{id}` | Cập nhật schedule |
| DELETE | `/api/v1/schedules/{id}` | Xóa schedule |
| GET | `/api/v1/sessions` | Liệt kê sessions |
| POST | `/api/v1/sessions` | Tạo session |
| GET | `/api/v1/sessions/{id}` | Chi tiết session |
| PATCH | `/api/v1/sessions/{id}` | Cập nhật session |
| DELETE | `/api/v1/sessions/{id}` | Xóa session |
| GET | `/api/v1/sessions/{id}/summary` | Attendance summary |
| POST | `/api/v1/sessions/generate-daily` | Tạo daily sessions |
| GET | `/api/v1/teachers` | Liệt kê teachers |
| POST | `/api/v1/teachers/{id}/assign-department` | Gán department |
| DELETE | `/api/v1/teachers/{id}/assign-department` | Bỏ gán department |

---

## 7. Dependencies

### Flutter
- `get_it` + `injectable` cho DI
- `flutter_bloc` cho Cubit
- `Dio` qua `ApiClient` wrapper
- `RequestStatus` enum cho state management

### Backend
- `SQLAlchemy` với `joinedload` cho eager-loading
- Không thêm package mới

---

## 8. Testing Checklist

- [ ] Tạo department → hiển thị trong danh sách
- [ ] Sửa department → dữ liệu cập nhật
- [ ] Xóa department → không còn hiển thị
- [ ] Tạo room → hiển thị trong danh sách
- [ ] Sửa room → dữ liệu cập nhật
- [ ] Tạo course với 3 attendance modes
- [ ] Cập nhật course → dữ liệu backend thay đổi
- [ ] Gán room cho course → `room_name` hiển thị đúng
- [ ] Tạo schedule với time slot picker
- [ ] Cập nhật schedule → thay đổi được day/time slot
- [ ] Xóa schedule → không còn hiển thị
- [ ] Tạo session → hiển thị trong danh sách
- [ ] Activate session → status chuyển sang "active"
- [ ] Close session → status chuyển sang "closed"
- [ ] Navigate từ session detail sang checking page với `sessionId`
- [ ] Generate daily sessions → tạo đúng sessions theo schedule
- [ ] Teacher assignment → gán/bỏ gán department thành công
- [ ] Course students → enroll/unenroll sinh viên
