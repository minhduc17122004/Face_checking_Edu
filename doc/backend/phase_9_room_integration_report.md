# Phase 9: Room Assignment Integration + Scaling — Implementation Report

**Date:** 2026-03-21
**Revision:** Phase 9 — Production Hardening (continuation)
**Status:** Completed

---

## 1. Tổng quan

Phase 9 hoàn thành việc chuẩn hóa domain **Room** cho hệ thống điểm danh khuôn mặt. Trước Phase 9, hệ thống lưu trữ vị trí phòng học dưới dạng chuỗi string (`room: str`) rải rác trong các bảng `devices` và `schedules`, dẫn đến:

- So sánh string không đáng tin cậy
- Không chuẩn hóa dữ liệu
- Không mở rộng được cho multi-campus
- Anti-cheat dựa trên so sánh string `device.room == schedule.room`

**Kết quả Phase 9:** Chuyển đổi từ string-based logic sang **relational domain model** với bảng `rooms` chuẩn hóa.

---

## 2. Database Migrations

### 2.1 Migration `0023_add_rooms_table.py`
- Tạo bảng `rooms` với các trường: `id` (UUID), `code` (UNIQUE), `name`, `building`, `floor`, `capacity`
- Hỗ trợ soft delete: `deleted_at`, `created_by`, `updated_by`
- CHECK constraint đảm bảo `code` không rỗng

### 2.2 Migration `0024_add_room_id_to_courses.py`
- Thêm `room_id` (UUID FK) vào bảng `courses`
- Index: `ix_courses_room_id`
- FK: `courses.room_id → rooms.id` (ON DELETE SET NULL)

### 2.3 Migration `0025_migrate_room_string_to_room_id.py`
- Chuyển đổi dữ liệu string hiện có từ `schedules.room` và `devices.room` vào bảng `rooms`
- Map `course.room_id` dựa trên `schedule.room` của course đó
- Map `device.room_id` bằng cách match `device.room == rooms.code`
- Idempotent: có `ON CONFLICT DO NOTHING` nên chạy nhiều lần không ảnh hưởng

### 2.4 Migration `0026_drop_schedule_device_room_columns.py`
- Xóa `schedules.room` (string)
- Xóa `devices.room` (string)
- **Lưu ý:** Migration này không thể đảo ngược — dữ liệu string sẽ mất

---

## 3. Room Module (Model — Schema — Repository — Service — Router)

### 3.1 `app/models/room.py` (NEW)
- Entity `Room` với các trường: `id`, `code`, `name`, `building`, `floor`, `capacity`
- Soft delete: `deleted_at`
- Relationships: `courses` (1-N), `devices` (1-N)
- Properties: `is_deleted`, `is_active`

### 3.2 `app/schemas/v1/room.py` (NEW)
- `RoomCreate`: `code`, `name`, `building`, `floor`, `capacity`
- `RoomUpdate`: tất cả trường optional
- `RoomOut`: response model với `from_attributes = True`
- `RoomList`: wrapper phân trang
- `AssignRoomRequest`: body cho `PUT /api/v1/courses/{id}/assign-room`

### 3.3 `app/repositories/room_repository.py` (NEW)
- `get_by_id()`, `get_by_code()` — lookup
- `list_active()` — phân trang
- `count_courses()` — đếm courses gắn với room
- `soft_delete()` — kế thừa từ BaseRepository

### 3.4 `app/services/room_service.py` (NEW)
- `create_room()` — tạo mới, kiểm tra trùng code
- `get_room()`, `get_room_by_code()`
- `list_rooms()` — phân trang
- `update_room()` — cập nhật, kiểm tra trùng code khi đổi
- `delete_room()` — **kiểm tra ràng buộc**: không xóa được nếu có courses hoặc devices liên kết

### 3.5 `app/routers/v1/rooms.py` (NEW)

| Method | Endpoint | Mô tả |
|--------|----------|--------|
| POST | `/api/v1/rooms/` | Tạo phòng mới |
| GET | `/api/v1/rooms/` | Danh sách phòng (phân trang) |
| GET | `/api/v1/rooms/{id}` | Chi tiết phòng |
| PUT | `/api/v1/rooms/{id}` | Cập nhật phòng |
| DELETE | `/api/v1/rooms/{id}` | Xóa mềm (kiểm tra ràng buộc) |

---

## 4. Refactor Course Model

### 4.1 Model Changes
- Thêm `room_id: Mapped[Optional[uuid.UUID]]` — FK đến `rooms.id`
- Thêm relationship `room: Mapped[Optional["Room"]]` với `back_populates="courses"`

### 4.2 Schema Changes
- `CourseCreate`: thêm `room_id: Optional[uuid.UUID]`
- `CourseOut`: thêm `room_id: uuid.UUID | None`

### 4.3 Repository Changes
- `CourseRepository.create()`: thêm param `room_id`
- `CourseRepository.update()`: thêm param `room_id`

### 4.4 Service Changes
- `CourseService.create_course()`: validate `room_id` tồn tại trước khi gán
- `CourseService.update_course()`: truyền `room_id` xuống repository

### 4.5 New Endpoint
```
PUT /api/v1/courses/{course_id}/assign-room
Body: {"room_id": "uuid"}
```
- Yêu cầu quyền owner của course
- Validate room tồn tại và active

---

## 5. Refactor Device Model

### 5.1 Model Changes
- **Loại bỏ:** `room: Mapped[Optional[str]]` (string column)
- **Thêm:** `room_id: Mapped[Optional[uuid.UUID]]` — FK đến `rooms.id`
- **Thêm:** relationship `room: Mapped[Optional["Room"]]`
- Cập nhật docstring và `__repr__`

### 5.2 Schema Changes
- `DeviceCreate`: `room: str | None` → `room_id: uuid.UUID | None`
- `DeviceUpdate`: tương tự
- `DeviceResponse`: tương tự

### 5.3 Repository Changes
- `DeviceRepository.get_by_room(room: str)` → `get_by_room(room_id: uuid.UUID)`
- Thay đổi điều kiện query: `Device.room_id == room_id`

### 5.4 Router Changes
- `register_device()`: sử dụng `room_id=req.room_id`
- `update_device()`: sử dụng `room_id=req.room_id`

---

## 6. Refactor Schedule Model

### 6.1 Model Changes
- **Loại bỏ hoàn toàn:** `room: Mapped[Optional[str]]` column
- Schedule **kế thừa room từ course** qua `course.room_id`

### 6.2 Schema Changes
- Loại bỏ `room` khỏi `ScheduleCreate`, `ScheduleOut`

### 6.3 Router Changes
- `create_schedule()`: loại bỏ `room=req.room`

---

## 7. Anti-Cheat & Validator Refactor (FK-based Room Matching)

### 7.1 AntiCheatService — `validate_device_for_session()`

**Trước Phase 9:**
```python
if device.room and session.schedule and session.schedule.room:
    if device.room != session.schedule.room:
        return False, "Device room does not match schedule room"
```

**Sau Phase 9 (FK-based):**
```python
if device.room_id is None:
    return True, "OK"  # Device not assigned, allow all
if session.course.room_id is None:
    return True, "OK"  # Course has no room, allow all
if device.room_id != session.course.room_id:
    return False, "Device room does not match course room"
```

- Sử dụng `joinedload(Session.course)` để eager-load course
- So sánh UUID FK thay vì string
- NULL-safe: nếu một trong hai bên NULL thì cho phép

### 7.2 AttendanceValidator — `validate_device()`

Cùng logic với AntiCheatService:
- `device.room_id == course.room_id` qua session.course
- Sử dụng `joinedload` để tránh N+1

### 7.3 DeviceService — `sync_data()`

**Trước Phase 9:**
```python
# Match schedules by room string
Schedule.room == device.room
Session.schedule_id.in_(schedule_ids)
```

**Sau Phase 9:**
```python
# Match courses by FK
Course.room_id == device.room_id
Session.course_id.in_(course_ids)
```

- Logic đơn giản hơn — không cần qua bảng schedule trung gian
- Lấy tất cả courses có `room_id` khớp với device

---

## 8. Redis Cache & Distributed Lock

### 8.1 `app/core/distributed_lock.py` (NEW)

Triển khai Redis SET NX lock với:

- **Lock key format:** `dlk:checkin:{session_id}:{student_id}`
- **TTL:** 30 giây (có thể cấu hình)
- **Lua script** để release — chỉ xóa nếu đúng holder (tránh xóa lock của process khác)
- **Graceful fallback:** Nếu Redis không khả dụng, skip lock (hoạt động như trước)
- **Timeout:** 5 giây để acquire lock, sau đó raise `LockAcquisitionError`

### 8.2 AttendanceService — `realtime_checkin()`

```python
try:
    async with checkin_lock(req.session_id, req.student_id):
        record = await self.create_attendance(...)
except LockAcquisitionError:
    raise HTTPException(status_code=429, detail="Too many requests...")
```

- **Chống race condition:** khi 100+ students check-in cùng lúc
- **Idempotent:** check trong lock đảm bảo không có duplicate attendance record
- **HTTP 429:** khi lock bị contention cao

### 8.3 Redis Client Management
- Lazy initialization — chỉ kết nối khi cần
- Connection timeout 2 giây
- Graceful degradation khi Redis down

---

## 9. Metrics Endpoint

### 9.1 `app/routers/v1/metrics.py` (NEW)

```
GET /api/v1/metrics/
```

Response:
```json
{
  "checkin_total": 15420,
  "checkin_today": 342,
  "active_sessions": 8,
  "total_students": 1250,
  "timestamp": "2026-03-21T10:30:00Z"
}
```

### 9.2 Repository Methods Added

**AttendanceRepository:**
- `count_total_checkins()` — tổng số check-ins
- `count_today_checkins()` — check-ins hôm nay
- `count_active_sessions()` — số sessions đang active

**SessionRepository:**
- `count_active()` — đếm sessions có status = "active"

---

## 10. Test Coverage

### 10.1 `tests/services/test_room_service.py`
- `test_create_room_success` — tạo phòng thành công
- `test_create_room_duplicate_code_fails` — trùng code → 409
- `test_get_room_by_code` — lookup bằng code
- `test_get_room_by_code_not_found` — 404
- `test_delete_room_with_linked_course_fails` — ràng buộc courses
- `test_delete_room_without_links_succeeds` — xóa thành công
- `test_assign_room_to_course` — gán phòng cho course

### 10.2 `tests/services/test_anti_cheat_room.py`
- `test_validate_device_matching_room_passes` — cùng room_id
- `test_validate_device_mismatched_room_fails` — khác room_id
- `test_validate_device_null_room_allows_all` — device không gán phòng
- `test_validate_course_null_room_allows_all_devices` — course không gán phòng

### 10.3 `tests/api/v1/test_room_api.py`
- `test_create_room_api` — API endpoint
- `test_list_rooms_pagination` — pagination
- `test_assign_room_to_course_requires_auth` — auth check

---

## 11. Kiến trúc cuối cùng

```
┌─────────────────────────────────────────────────────────────┐
│                        rooms (TABLE)                        │
│  id | code | name | building | floor | capacity            │
└──────────┬─────────────────────────────────────────────────┘
           │
     ┌─────┴──────┐
     │             │
┌────▼─────┐  ┌───▼──────┐
│ courses  │  │ devices  │
│          │  │          │
│ room_id ─┼─►│ room_id  │
│          │  │          │
│ schedules│  │          │
│ (inherits│  │          │
│  room via│  │          │
│  course) │  │          │
└─────┬────┘  └─────┬────┘
      │              │
      │   ┌──────────┘
      │   │
┌─────▼───▼──────┐
│    sessions    │
│                 │
│ course_id ──────┼──► course.room_id == device.room_id
│                 │    (Anti-cheat FK-based matching)
│ checkin_window  │
│   start/end     │
└───────┬─────────┘
        │
        ▼
┌─────────────────┐
│   attendance    │
│ (session_id,    │
│  student_id)    │
│  UNIQUE         │
└─────────────────┘
```

**Luồng Anti-Cheat mới:**
1. Device gửi check-in: `device_id`, `session_id`, `student_id`
2. AntiCheatService: `device.room_id == session.course.room_id`
3. AttendanceValidator: validate đầy đủ
4. Distributed lock: chống race condition
5. Attendance created (idempotent)

---

## 12. Breaking Changes

| Thay đổi | Ảnh hưởng | Xử lý |
|----------|-----------|--------|
| Xóa `schedule.room` | API `POST /schedules` — bỏ field `room` | Update frontend/giao diện |
| Xóa `device.room` | API `POST /devices`, `PATCH /devices` — dùng `room_id` | Migration dữ liệu |
| String → FK | Dữ liệu cũ được migrate tự động | Chạy migration 0023-0026 |
| Course.room_id nullable | Courses không bắt buộc có phòng | OK — anti-cheat cho phép |

---

## 13. Migration Order

```
alembic upgrade head
```

Thứ tự tự động:
1. `0023_add_rooms_table`
2. `0024_add_room_id_to_courses`
3. `0025_migrate_room_string_to_room_id` (data migration)
4. `0026_drop_schedule_device_room_columns` (drop columns)

**Cảnh báo:** Migration 0025 và 0026 không thể đảo ngược hoàn toàn. Backup database trước khi chạy.

---

## 14. Files Changed Summary

| Stage | File | Type |
|-------|------|------|
| 1 | `alembic/versions/0023_add_rooms_table.py` | Migration |
| 1 | `alembic/versions/0024_add_room_id_to_courses.py` | Migration |
| 1 | `alembic/versions/0025_migrate_room_string_to_room_id.py` | Migration |
| 1 | `alembic/versions/0026_drop_schedule_device_room_columns.py` | Migration |
| 2 | `app/models/room.py` | New |
| 2 | `app/schemas/v1/room.py` | New |
| 2 | `app/repositories/room_repository.py` | New |
| 2 | `app/services/room_service.py` | New |
| 2 | `app/routers/v1/rooms.py` | New |
| 2 | `app/models/__init__.py` | Modified |
| 2 | `app/schemas/v1/__init__.py` | Modified |
| 2 | `app/repositories/__init__.py` | Modified |
| 2 | `app/services/__init__.py` | Modified |
| 2 | `app/routers/v1/__init__.py` | Modified |
| 3 | `app/models/course.py` | Modified |
| 3 | `app/schemas/v1/course.py` | Modified |
| 3 | `app/repositories/course_repository.py` | Modified |
| 3 | `app/services/course_service.py` | Modified |
| 3 | `app/routers/v1/courses.py` | Modified |
| 4 | `app/models/device.py` | Modified |
| 4 | `app/schemas/v1/device.py` | Modified |
| 4 | `app/repositories/device_repository.py` | Modified |
| 4 | `app/routers/v1/devices.py` | Modified |
| 5 | `app/models/schedule.py` | Modified |
| 5 | `app/schemas/v1/schedule.py` | Modified |
| 5 | `app/routers/v1/schedules.py` | Modified |
| 6 | `app/services/anti_cheat_service.py` | Modified |
| 6 | `app/services/attendance_validator.py` | Modified |
| 7 | `app/core/distributed_lock.py` | New |
| 7 | `app/services/attendance_service.py` | Modified |
| 7 | `app/services/device_service.py` | Modified |
| 8 | `app/routers/v1/metrics.py` | New |
| 8 | `app/repositories/attendance_repository.py` | Modified |
| 8 | `app/repositories/session_repository.py` | Modified |
| 8 | `app/routers/v1/__init__.py` | Modified |
| 9 | `tests/services/test_room_service.py` | New |
| 9 | `tests/services/test_anti_cheat_room.py` | New |
| 9 | `tests/api/v1/test_room_api.py` | New |

**Tổng cộng:** 4 migrations + 7 new files + 14 modified files + 3 test files

---

## 15. Performance Improvements

| Vấn đề | Trước | Sau |
|--------|-------|-----|
| Room matching | String comparison (`device.room == schedule.room`) | FK comparison (`device.room_id == course.room_id`) |
| Device sync | Match schedules → extract course_ids | Direct: `Course.room_id == Device.room_id` |
| Locking | None | Redis distributed lock |
| Metrics | Manual counting | Pre-computed aggregates |
| Session-course-room | Indirect via schedule | Direct FK relationship |

---

## 16. Next Steps (Recommendations)

1. **Chạy migration** trên staging trước production
2. **Backup database** trước khi upgrade
3. **Update Flutter frontend** — thay `device.room` bằng `device.room_id` picker
4. **Thêm endpoint** `GET /api/v1/rooms/{id}/courses` để liệt kê courses trong một phòng
5. **Cân nhắc** thêm `GET /api/v1/devices/{id}/assign-room` để gán phòng cho device
6. **Monitoring:** Expose metrics qua Prometheus endpoint
7. **Load test** với Redis lock — 100+ concurrent check-ins
