# Phase 9: Device-based Attendance Management — Implementation Report

---

## Tổng quan

Đã triển khai hoàn chỉnh **Phase 9: Device-based Attendance Management**, cho phép tablet/admin mode thực hiện điểm danh hàng loạt theo phòng học và buổi học. Tổng cộng **~60 file** được tạo mới hoặc chỉnh sửa.

---

## Phần 1: Backend — FastAPI

### 1.1. Database Models (`backend/app/models/`)

#### Files mới

| File | Mô tả |
|------|-------|
| `attendance_config.py` | Cấu hình điểm danh per-session: `session_id`, `early_allowance`, `late_allowance` (minutes) |
| `device_request.py` | Yêu cầu quyền thiết bị: `device_code`, `device_name`, `room_id`, `status` (PENDING/APPROVED/REJECTED), `reviewed_by`, `admin_note`, timestamps |

#### Files sửa

| File | Thay đổi |
|------|----------|
| `session.py` | Thêm relationship `attendance_config: Mapped[Optional["AttendanceConfig"]]` |
| `room.py` | Thêm relationships `device_requests`, `attendance_records` |
| `user.py` | Thêm relationships `device_requests` (requester), `device_reviewed_requests` (reviewer) |
| `device.py` | Thêm trường `is_global: bool`, `status: str`; relationship `room` đã có sẵn |
| `attendance.py` | Thêm `minutes_diff: Optional[int]`, `room_id: Optional[UUID]` |

### 1.2. Pydantic Schemas (`backend/app/schemas/v1/`)

#### Files mới

| File | Schemas |
|------|---------|
| `device_request.py` | `DeviceRequestCreate`, `DeviceRequestSubmit`, `ApproveRequest`, `RejectRequest`, `DeviceRequestResponse`, `DeviceRequestList` |
| `attendance_config.py` | `AttendanceConfigCreate`, `AttendanceConfigUpdate`, `AttendanceConfigResponse` |
| `room_session.py` | `RoomSessionResponse` (session + course_name + attendance_count + total_enrolled), `RoomSessionList` |
| `attendance_checkin.py` | `ManualCheckinRequest`, `ManualCheckinResponse`, `AttendanceRecordResponse`, `AttendanceCheckinList`, `AttendanceSummaryResponse` |

#### Files sửa

| File | Thay đổi |
|------|----------|
| `device.py` | Thêm `is_global`, `status` vào `DeviceCreate`, `DeviceUpdate`, `DeviceResponse` |
| `__init__.py` | Export tất cả schemas mới |

### 1.3. Repository Layer (`backend/app/repositories/`)

#### Files mới

| File | Methods |
|------|---------|
| `attendance_config_repository.py` | `get_by_session`, `upsert` |
| `device_request_repository.py` | `get_by_id`, `get_by_device_code`, `get_pending`, `list_all`, `create`, `approve`, `reject`, `soft_delete` |

#### Files sửa

| File | Thay đổi |
|------|----------|
| `device_repository.py` | Thêm `get_by_room_or_global` — lọc thiết bị theo room hoặc global |
| `session_repository.py` | Thêm `get_by_room` và `get_by_room_sorted` — lấy sessions theo room với sort: active → scheduled → closed, rồi theo `start_time` |
| `attendance_repository.py` | Cập nhật `create` để nhận `minutes_diff` và `room_id` |

### 1.4. Service Layer (`backend/app/services/`)

#### Files mới

| File | Methods |
|------|---------|
| `attendance_config_service.py` | `get_config`, `create_or_update`, `update_config`, `get_effective_config` |
| `device_request_service.py` | `submit_request`, `list_requests`, `get_request`, `approve_request`, `reject_request`, `get_my_requests` |
| `device_authorization_service.py` | `check_device_access` — kiểm tra `is_global`, room match, và approved request; `update_device_status` |

#### Files sửa

| File | Thay đổi |
|------|----------|
| `attendance_service.py` | Thêm `AttendanceConfigService` và `DeviceAuthorizationService`; sửa `create_attendance` dùng `_validate_checkin_window` (tính `minutes_diff`, set `room_id`); thêm `manual_checkin`, `get_session_checkins`, `get_enhanced_summary` |
| `__init__.py` | Export 3 service mới |

### 1.5. API Routers (`backend/app/routers/v1/`)

#### Files mới

| File | Endpoints |
|------|-----------|
| `device_requests.py` | `POST /` (submit), `GET /me` (my requests), `GET /` (list all), `GET /{id}`, `PATCH /{id}/approve`, `PATCH /{id}/reject` |
| `attendance_configs.py` | `POST /` (create/update), `GET /{session_id}`, `PATCH /{session_id}` |
| `room_sessions.py` | `GET /rooms/{id}/sessions` — trả về sessions với course_name, attendance_count, total_enrolled, sorted active → scheduled → closed |

#### Files sửa

| File | Thay đổi |
|------|----------|
| `attendance.py` | Thêm `POST /check-in` (manual), `GET /session/{id}/checkins`, `GET /session/{id}/summary` |
| `devices.py` | Cập nhật `register_device` và `update_device` xử lý `is_global`, `status` |
| `__init__.py` | Đăng ký 3 router mới: `device_requests_router`, `attendance_configs_router`, `room_sessions_router` |

### 1.6. Alembic Migration (`backend/alembic/versions/`)

| File | Nội dung |
|------|----------|
| `0029_add_device_attendance_tables.py` | `down_revision = "fc7a550c7bb0"`; `upgrade()`: tạo `attendance_configs` và `device_requests`, thêm `is_global`/`status` vào `devices`, thêm `minutes_diff`/`room_id` vào `attendance`; `downgrade()`: revert toàn bộ |

---

## Phần 2: Flutter App

### 2.1. Entities (`lib/entities/`)

| File | Nội dung |
|------|----------|
| `device.dart` | Entity `Device` với `id`, `deviceCode`, `deviceName`, `roomId`, `isGlobal`, `status`, các getters `isGlobalFlag`, `isActive`, `isOnline` |
| `device_request.dart` | Enum `DeviceRequestStatus` (pending/approved/rejected) với `fromString`, `value`, `label`; Entity `DeviceRequest` với helper getters `isPending`, `isApproved`, `isRejected` |
| `attendance_config.dart` | Entity `AttendanceConfig` với `id`, `sessionId`, `earlyAllowance`, `lateAllowance` |
| `room_session.dart` | Entity `RoomSession` với `courseName`, `sessionDate`, `attendanceCount`, `totalEnrolled`, getters `absentCount`, `attendanceRate`, `isActive`, `isScheduled`, `isClosed`, `formattedDate`, `formattedStartTime`, `formattedEndTime` |
| `attendance_record_ui.dart` | Entity `AttendanceRecordUI` với `studentName`, `studentCode`, `minutesDiff`, getters `isPresent`, `isLate`, `formattedCheckinTime`, `minutesDiffLabel`, `displayName` |

### 2.2. API Services (`lib/data/remote/`)

| File | Methods |
|------|---------|
| `device_service.dart` | `registerDevice`, `getDevice`, `updateDevice`, `getDevices` |
| `device_request_service.dart` | `submitRequest`, `getMyRequests`, `getAllRequests`, `getRequest`, `approveRequest`, `rejectRequest` |
| `room_session_service.dart` | `getRooms`, `getRoomSessions` (với optional `sessionDate` filter) |
| `attendance_checkin_service.dart` | Helper classes `ManualCheckinResult`, `AttendanceCheckinSummary`; methods `manualCheckin`, `getSessionCheckins`, `getSessionSummary` |

**File sửa:** `api_endpoint.dart` — thêm constants: `deviceRequests`, `deviceRequestsMe`, `attendanceConfigs`, `roomSessions`, `attendanceCheckin`, `attendanceSessionCheckins`, `attendanceSessionSummary`

### 2.3. State Classes

#### Files mới

| File | Class | Mô tả |
|------|-------|-------|
| `setting/cubit/device_permission/device_permission_cubit.dart` | `DevicePermissionCubit` | Quản lý device permission requests: `loadMyRequests`, `loadAllRequests`, `submitRequest`, `approveRequest`, `rejectRequest`, `reset` |
| `setting/cubit/device_permission/device_permission_state.dart` | `DevicePermissionState` | State với `myRequests`, `allRequests`, `selectedRequest`, `message`; getters `hasApprovedRequest`, `latestRequest`, `myLatestStatus` |
| `room/bloc/room_session_bloc.dart` | `RoomSessionBloc` | Quản lý rooms và sessions: `loadRooms`, `loadRoomSessions` (với optional `sessionDate`), `selectRoom`, `reset` |
| `room/bloc/room_session_state.dart` | `RoomSessionState` | State với `rooms`, `sessions`, `selectedRoom`; getters `activeSessions`, `scheduledSessions`, `closedSessions` |
| `attendance_checkin/bloc/attendance_checkin_bloc.dart` | `AttendanceCheckinBloc` | Quản lý check-in: `loadSessionCheckins`, `loadSessionSummary`, `manualCheckin`, `hasRecordForStudent`, `reset` |
| `attendance_checkin/bloc/attendance_checkin_state.dart` | `AttendanceCheckinState` | State với `records`, `summary`, `lastCheckin`, `message`; getters `totalCount`, `presentCount`, `lateCount` |

### 2.4. Pages (`lib/pages/`)

#### Files mới

| File | Mô tả |
|------|-------|
| `setting/device_permission_page.dart` | Danh sách yêu cầu quyền thiết bị với filter chips (Tất cả/Đang chờ/Đã duyệt/Từ chối); card hiển thị device name, code, room, status; nút Duyệt/Từ chối cho admin; dialog nhập ghi chú khi từ chối |
| `room/room_list_page.dart` | Danh sách phòng học với icon, tên, mã, tòa nhà, sức chứa; navigation tới `RoomSessionPage` |
| `room/room_session_page.dart` | Danh sách sessions theo phòng, phân loại: Đang diễn ra (xanh), Sắp tới (xanh dương), Đã kết thúc (xám); filter theo ngày; card hiển thị course, thời gian, sĩ số; navigation tới `AttendanceCheckinPage` |
| `attendance_checkin/attendance_checkin_page.dart` | Summary card với 4 chỉ số (Đã điểm danh, Đúng giờ, Trễ, Vắng) và progress bar; danh sách bản ghi với icon màu theo trạng thái, tên sinh viên, thời gian check-in, chênh lệch phút |

#### Files sửa

| File | Thay đổi |
|------|----------|
| `setting/setting_page.dart` | Thêm menu item "Yêu cầu quyền thiết bị" trong phần admin, navigate tới `DevicePermissionPage` |

### 2.5. Route Registration (`lib/route/`)

**File sửa:** `app_route.dart`

- Thêm constants: `devicePermission` (`/settings/device-permission`), `roomSessions` (`/rooms/sessions`), `attendanceCheckin` (`/attendance-checkin`)
- Thêm switch cases cho 3 route mới
- Import 3 page files tương ứng

### 2.6. Dependency Injection (`lib/di/`)

Sau khi import các service và cubit mới, chạy lệnh regenerate:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Kết quả `injection.config.dart`:**

| Type | Name | Annotation |
|------|------|------------|
| Service | `AttendanceCheckinService` | `@LazySingleton` |
| Service | `DeviceRequestService` | `@LazySingleton` |
| Service | `RoomSessionService` | `@LazySingleton` |
| Cubit | `AttendanceCheckinBloc` | `@factory` |
| Cubit | `RoomSessionBloc` | `@factory` |
| Cubit | `DevicePermissionCubit` | `@factory` |

### 2.7. Widget Components

| File | Mô tả |
|------|-------|
| `room/widgets/session_card.dart` | Card hiển thị session với status badge, course name, thời gian, sĩ số, attendance rate |
| `attendance_checkin/widgets/attendance_student_list.dart` | Danh sách sinh viên đã điểm danh với avatar, tên, mã, thời gian, trạng thái |
| `attendance_checkin/widgets/checkin_counter.dart` | Badge hiển thị số lượng đã điểm danh / tổng sĩ số |

---

## Business Logic quan trọng

### Time Window Validation

```
Check-in hợp lệ khi: NOW ∈ [start_time - early_allowance, end_time + late_allowance]
```

### Status Calculation

```
delta = checkin_time - start_time
delta < 0  → "present"  (sớm)
delta = 0  → "present"  (đúng giờ)
delta > 0  → "late"     (trễ)
minutes_diff = abs(delta in minutes)
```

### Session Sorting

```sql
ORDER BY
  CASE WHEN start_time <= NOW() AND end_time >= NOW() THEN 0 ELSE 1 END,
  start_time ASC
```

### Device Authorization

```
is_global=true  → access mọi room
is_global=false → chỉ access room_id được gán
```

---

## Bugs đã fix trong quá trình triển khai

1. **Duplicate `attendance_mode` property** trong `session.py` — đã xóa duplicate
2. **Relationship sai** trong `device.py` cho `device_requests` — đã revert, `DeviceRequest` dùng `device_code` string, không phải FK UUID
3. **Naming conflict** `CheckinRequest`/`CheckinResponse` trong `attendance_checkin.py` — đã rename thành `ManualCheckinRequest`/`ManualCheckinResponse`
4. **Logic sort sai** trong `session_repository.py` `get_by_room_sorted` (if/else không đúng) — đã thay bằng `sqlalchemy.case`
5. **Import thừa** trong `session_repository.py` (`datetime.now`) — đã xóa
6. **Flutter color syntax** `AppColors.blue.withOpacity(0.1)` — đã chuẩn hóa thành `withValues(alpha: 0.1)`
7. **Navigation arguments** `RoomSessionPage` truyền `session` trực tiếp — đã wrap thành `AttendanceCheckinArgs`
8. **Type error** `hasRecordForStudent` getter trả về function thay vì `bool` trong `attendance_checkin_state.dart` — đã xóa getter, `AttendanceCheckinBloc` đã có method tương ứng

---

## Cấu trúc file tổng quan

```
Backend:
  models/         → 2 file mới, 5 file sửa
  schemas/v1/      → 4 file mới, 2 file sửa
  repositories/    → 2 file mới, 3 file sửa
  services/        → 3 file mới, 2 file sửa
  routers/v1/      → 3 file mới, 3 file sửa
  alembic/         → 1 migration file mới

Flutter:
  entities/        → 5 file mới
  data/remote/    → 4 file mới, 1 file sửa
  pages/          → 7 file mới, 4 file sửa
  widgets/        → 3 file mới
  route/          → 2 file sửa
  di/             → 1 file sửa (regenerate)
```

---

## Lưu ý quan trọng

- Flutter dùng **manual state classes** với `RequestStatus` enum (KHÔNG dùng Freezed)
- Flutter dùng **manual routing** với `MaterialPageRoute` (KHÔNG dùng go_router/auto_route)
- Backend dùng **async SQLAlchemy** 2.x với `asyncpg`
- Tất cả Flutter state classes phải có `copyWith()` method
- Backend dùng **soft delete** pattern (`deleted_at IS NULL`)
- API responses dùng `DataState<T>` pattern với `DataSuccess`/`DataFailed`
