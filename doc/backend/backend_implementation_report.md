# Backend Implementation Report — Face Time Keeping System

> **Ngày cập nhật:** 2026-03-21
> **Trạng thái:** Hoàn thành (Phase 1–8 + Migration 0014)
> **Framework:** FastAPI + SQLAlchemy 2.x (async) + PostgreSQL + Alembic

---

## Tổng quan kiến trúc

```
┌─────────────────────────────────────────────────────────────┐
│                        FastAPI App                           │
├─────────────────────────────────────────────────────────────┤
│  v1 Routers (/api/v1/*)     │  Legacy Routers (Flutter)   │
│  Production-ready            │  /auth, /api, /attendance/* │
├─────────────────────────────────────────────────────────────┤
│                    Service Layer                            │
│  AttendanceService, AuthService, AntiCheatService...       │
├─────────────────────────────────────────────────────────────┤
│                  Repository Layer                           │
│  BaseRepository (soft-delete), 13 repositories             │
├─────────────────────────────────────────────────────────────┤
│                SQLAlchemy 2.x Async ORM                    │
├─────────────────────────────────────────────────────────────┤
│                    PostgreSQL                               │
│  16 Alembic Migrations (0001 → 0014)                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Mixins & Models — Đồng nhất hóa tất cả models

### 1.1 Tạo Mixins

**File:** `app/models/_mixins.py`

```python
class SoftDeleteMixin:
    # NOTE: is_deleted was removed in migration 0014
    # Only deleted_at is used going forward
    deleted_at: Mapped[Optional[datetime]] = DateTime(timezone=True, nullable=True)

class AuditMixin:
    created_by: Mapped[Optional[uuid.UUID]] = None
    updated_by: Mapped[Optional[uuid.UUID]] = None
```

### 1.2 Cập nhật Models

| File | Thay đổi |
|------|-----------|
| `attendance.py` | **Xóa `user_id`** (đồng nhất chỉ dùng `student_id`). Thêm `CheckConstraint` cho `status`. Thêm index `ix_attendance_session_student` |
| `face_embedding.py` | **Xóa `user_id`** (chỉ dùng `student_id`). Thêm index `ix_face_embeddings_student_id`. Đổi tên `embedding_data` → `embedding` |
| `student.py` | **Xóa `job_title`, `name`, `avatar_url`, `has_avatar`, `attachment_id`, `is_synced`** (đã chuyển sang User model). Đổi `academic_class_id` → `student_group_id` |
| `course.py` | Đổi tên: `class_name` → `course_name`, `teacher_id` → `instructor_id`, bảng `classes` → `courses` |
| `session.py` | Đổi `classroom_id` → `course_id`. Thêm `checkin_window_start/end`, `session_date` |
| `schedule.py` | Đổi `classroom_id` → `course_id`. Đổi `subject_name` → `room` |
| `device.py` | Đổi `classroom_id` → `course_id`. Thêm `device_name`, `mac_address` |
| `course_enrollment.py` | Đổi tên: bảng `classroom_students` → `course_enrollments` |
| `student_group.py` | Đổi tên: bảng `academic_classes` → `student_groups` |
| `teacher.py` | Đổi `employee_code` → `teacher_id`. Xóa `avatar_url` |
| `user.py` | Xóa `attendances` relationship. Chỉ dùng `deleted_at`, không có `is_deleted` |
| `__init__.py` | **Sửa bug nghiêm trọng:** xóa `AttendanceRecord` (model không tồn tại). Thêm `RefreshToken`, `_mixins`. Export aliases `Classroom = Course`, `ClassroomStudent = CourseEnrollment`, `AcademicClass = StudentGroup` |

### 1.3 Bug đã fix

- **`AttendanceRecord` không tồn tại:** `attendance_repository.py` import `AttendanceRecord` nhưng model chỉ định nghĩa `Attendance`. Đã refactor toàn bộ để dùng `Attendance`.
- **`is_deleted` vs `deleted_at`:** Tất cả models chuyển sang chỉ dùng `deleted_at`.

---

## Phase 2: Database Migration 0011

**File:** `alembic/versions/0011_unify_attendance_identity.py`

```sql
-- 1. Xóa user_id khỏi attendance
ALTER TABLE attendance DROP COLUMN IF EXISTS user_id;

-- 2. Xóa user_id khỏi face_embeddings
ALTER TABLE face_embeddings DROP COLUMN IF EXISTS user_id;

-- 3. Indexes mới
CREATE INDEX ix_attendance_session_student ON attendance (session_id, student_id);
CREATE INDEX ix_attendance_checkin_time ON attendance (checkin_time);
CREATE INDEX ix_sessions_course_start ON sessions (course_id, start_time);
CREATE INDEX ix_course_enrollments_course_student ON course_enrollments (course_id, student_id);
```

---

## Phase 3: Repository Layer — Nền tảng dữ liệu

### 3.1 Base Repository

**File:** `app/repositories/_base.py`

```python
class BaseRepository(Generic[ModelT]):
    # Tự động lọc deleted_at IS NULL trên tất cả queries
    # Cung cấp: get_by_id(), list(), count(), add(), soft_delete()
```

### 3.2 Các Repository đã tạo/cập nhật

| Repository | File | Mô tả |
|-----------|------|--------|
| `BaseRepository` | `_base.py` | Base class với soft-delete filter |
| `AttendanceRepository` | `attendance_repository.py` | **Refactor hoàn toàn:** dùng `Attendance`. Hỗ trợ session-based, soft-delete |
| `SessionRepository` | `session_repository.py` | Mới: CRUD sessions, lọc theo course/date/status, auto-update status |
| `ScheduleRepository` | `schedule_repository.py` | Mới: CRUD schedules, lọc theo course/day |
| `TimeSlotRepository` | `time_slot_repository.py` | Mới: reference data (không soft-delete) |
| `CourseEnrollmentRepository` | `course_enrollment_repository.py` | Mới: enrollment management, `find_enrollment()`, `get_students_with_face_status()` |
| `StudentGroupRepository` | `student_group_repository.py` | Mới: CRUD student groups, `get_by_code()` |
| `CourseRepository` | `course_repository.py` | Mới: CRUD courses |
| `TeacherRepository` | `teacher_repository.py` | Mới |
| `DeviceRepository` | `device_repository.py` | Mới: CRUD devices, `get_by_code()`, `get_active()` |
| `UserRepository` | `user_repository.py` | **Cập nhật:** thêm soft-delete filter, nhận `str \| UUID` |
| `StudentRepository` | `student_repository.py` | **Cập nhật:** thêm soft-delete filter |
| `FaceRepository` | `face_repository.py` | **Cập nhật:** thêm filter `is_active == True` |

### 3.3 Thiết kế Repository

```
BaseRepository (generic)
├── get_by_id(id)        → tự động filter deleted_at IS NULL
├── list(skip, limit)     → trả về (items, total)
├── count()              → đếm bản ghi active
├── add(instance)        → flush
└── soft_delete(instance) → deleted_at=now

Subclass overrides model = X
```

---

## Phase 4: Service Layer — Business Logic

### 4.1 Base Service

**File:** `app/services/_base.py`

```python
class BaseService:
    def __init__(self, db: AsyncSession, user_id: str | None = None):
        self.db = db
        self.user_id = user_id  # cho audit trail
```

### 4.2 Anti-Cheat Service

**File:** `app/services/anti_cheat_service.py`

```python
class AntiCheatService:
    validate_session_exists(session_id)
        → Kiểm tra session tồn tại, không bị xóa mềm

    validate_device_for_session(device_id, session_id)
        → Device phải thuộc cùng course với session

    validate_checkin_window(session_id, checkin_time)
        → Kiểm tra session.status == "active"
        → checkin phải trong khoảng checkin_window_start → checkin_window_end

    detect_duplicate_attendance(session_id, student_id)
        → Kiểm tra student chưa có attendance trong session này

    update_device_last_active(device_id)
        → Cập nhật last_active_at
```

### 4.3 Attendance Service (Unified)

**File:** `app/services/attendance_service.py`

```python
class AttendanceService:
    create_attendance(req: AttendanceCreate)
        1. Validate session exists
        2. Auto-detect "late" status
        3. Validate student exists
        4. Validate device (anti-cheat)
        5. Validate checkin window (anti-cheat)
        6. Detect duplicate (anti-cheat)
        7. Create record

    get_by_session(session_id) → AttendanceList
    get_by_student(student_id) → AttendanceList
    get_session_summary(session_id) → AttendanceSummary
        → Trả về {present, late, absent, attendance_rate}
    delete_attendance(id) → soft-delete
```

---

## Phase 5: Authentication & RBAC

### 5.1 Refresh Token Model

**File:** `app/models/refresh_token.py`

```python
class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: UUID (primary key)
    user_id: UUID (FK → users, CASCADE)
    token_jti: str(64)     # hashed JWT jti claim
    device_id: str|None    # multi-device support
    device_info: JSONB|None # metadata: browser, OS
    expires_at: datetime   # auto-expiry
    revoked: bool         # revocation flag
    created_at: datetime
```

**Tính năng:**
- Mỗi refresh token được hash trước khi lưu (bảo mật)
- Hỗ trợ revoke token cụ thể hoặc revoke tất cả tokens của user
- Có `expires_at` tự động hết hạn

### 5.2 JWT Token Flow

**File:** `app/core/security.py`

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Register   │────▶│ Access Token │     │             │
│   / Login   │────▶│  (15 phút)  │     │  /refresh    │
└──────────────┘     └──────────────┘     │  (7 ngày)   │
                              │            └──────┬───────┘
                              │                   │
                              ▼                   ▼
                        ┌──────────────┐   ┌──────────────┐
                        │ verify_token │   │ save_refresh │
                        └──────────────┘   │ _token()     │
                                            └──────────────┘
```

**Các function mới:**
- `create_refresh_token(subject, expires_delta)` → JWT với claim `type: "refresh"`
- `decode_refresh_token(token)` → verify + check `type == "refresh"`
- `save_refresh_token(user_id, token, device_id)` → hash + lưu vào DB
- `revoke_refresh_token(user_id, token)` → đánh dấu revoked
- `revoke_all_user_tokens(user_id)` → revoke tất cả tokens
- `is_token_revoked(user_id, token)` → kiểm tra revoked/expired

### 5.3 RBAC Decorator

**File:** `app/core/rbac.py`

```python
@require_role("admin", "teacher")
async def admin_endpoint(user_id: str = Depends(get_current_user_id)):
    """Chỉ admin và teacher được phép truy cập"""
    ...

# Cách dùng:
@router.get("/admin-panel")
async def admin_panel(
    user = Depends(require_role("admin"))
):
    return {"admin": user}
```

### 5.4 Migration 0012

**File:** `backend/alembic/versions/0012_add_refresh_tokens_and_device_auth.py`

```sql
-- 1. Refresh tokens table
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_jti VARCHAR(64) NOT NULL,
    device_id VARCHAR(255),
    device_info JSONB,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX ix_refresh_tokens_token_jti ON refresh_tokens(token_jti);

-- 2. Device authentication fields
ALTER TABLE devices ADD COLUMN device_secret VARCHAR(255);
ALTER TABLE devices ADD COLUMN api_key VARCHAR(64);
ALTER TABLE devices ADD COLUMN last_token_at TIMESTAMPTZ;
```

### 5.5 Cập nhật Config

**File:** `app/core/config.py`

```python
ACCESS_TOKEN_EXPIRE_MINUTES: int = 15    # Giảm từ 24 giờ → 15 phút
REFRESH_TOKEN_EXPIRE_DAYS: int = 7       # Mới: 7 ngày
```

---

## Phase 6: Error Handling & Database

### 6.1 Global Exception Handlers

**File:** `app/main.py`

| Exception | HTTP Status | Message |
|-----------|------------|---------|
| `RequestValidationError` | 422 | "Request validation failed" |
| `HTTPException` | Tự giữ nguyên | Tự giữ nguyên |
| `IntegrityError` (unique) | 409 | "Duplicate entry" |
| `IntegrityError` (FK) | 422 | "Referenced record not found" |
| `OperationalError` | 503 | "Database temporarily unavailable" |
| `DataError` | 422 | "Invalid data" |
| `Exception` (generic) | 500 | "Internal server error" |

### 6.2 Database Session

**File:** `app/core/database.py`

```python
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()      # Commit on success
        except Exception:
            await session.rollback()    # Rollback on error
            raise
        finally:
            await session.close()       # Luôn đóng session
```

---

## Phase 7: API v1 — Schemas & Routers

### 7.1 Schema Files (`app/schemas/v1/`)

| File | Schema Classes |
|------|--------------|
| `auth.py` | `LoginRequest`, `RegisterRequest`, `RefreshRequest`, `TokenResponse`, `UserInfo`, `MessageResponse`, `AvatarUploadResponse` |
| `attendance.py` | `AttendanceCreate`, `AttendanceOut`, `AttendanceWithDetails`, `AttendanceList`, `AttendanceSummary` |
| `session.py` | `SessionCreate`, `SessionUpdate`, `SessionOut`, `SessionWithSchedule`, `SessionList` |
| `student.py` | `StudentCreate`, `StudentOut`, `StudentList` |
| `course.py` | `CourseCreate`, `CourseOut`, `CourseList` |
| `device.py` | `DeviceCreate`, `DeviceUpdate`, `DeviceResponse`, `DeviceSyncResponse`, `BulkAttendanceRequest`, `BulkAttendanceResponse` |
| `user.py` | `UserOut`, `UserList` |
| `schedule.py` | `ScheduleCreate`, `ScheduleOut`, `ScheduleWithTimeSlot`, `ScheduleList` |
| `time_slot.py` | `TimeSlotCreate`, `TimeSlotOut`, `TimeSlotList` |
| `course_enrollment.py` | `CourseEnrollmentCreate`, `CourseEnrollmentOut`, `CourseEnrollmentList` |
| `student_group.py` | `StudentGroupCreate`, `StudentGroupUpdate`, `StudentGroupOut`, `StudentGroupList` |
| `face.py` | `FaceRegisterRequest`, `FaceStatusResponse`, `FaceBulkExport` |
| `common.py` | `PaginationParams`, `PaginatedResponse`, `ErrorDetail` |

### 7.2 Router Files (`app/routers/v1/`)

| Router | Prefix | Endpoints |
|--------|--------|-----------|
| `auth.py` | `/api/v1/auth` | `POST /register`, `POST /login`, `POST /refresh`, `GET /me`, `POST /avatar`, `POST /logout` |
| `attendance.py` | `/api/v1/attendance` | `POST /`, `GET /session/{id}`, `GET /student/{id}`, `GET /{id}`, `DELETE /{id}`, `GET /summary/session/{id}` |
| `sessions.py` | `/api/v1/sessions` | `POST /`, `GET /`, `GET /{id}`, `PUT /{id}`, `PATCH /{id}/status`, `DELETE /{id}`, `GET /{id}/summary` |
| `students.py` | `/api/v1/students` | `POST /`, `GET /`, `GET /{id}` |
| `courses.py` | `/api/v1/courses` | `POST /`, `GET /`, `GET /{id}`, `PUT /{id}`, `DELETE /{id}`, `GET /{id}/students`, `POST /{id}/students/{student_id}`, `DELETE /{id}/students/{student_id}` |
| `devices.py` | `/api/v1/devices` | `POST /`, `GET /`, `GET /{id}`, `PUT /{id}`, `DELETE /{id}`, `GET /{id}/sync`, `POST /bulk-attendance` |
| `faces.py` | `/api/v1/students/{id}/face` | `POST /`, `GET /face-status`, `GET /courses/{id}/face-embeddings` |
| `users.py` | `/api/v1/users` | `GET /`, `GET /{id}` |
| `schedules.py` | `/api/v1/schedules` | `POST /`, `GET /`, `GET /{id}`, `PUT /{id}`, `DELETE /{id}` |
| `time_slots.py` | `/api/v1/time-slots` | `POST /`, `GET /`, `GET /{id}` |
| `course_enrollments.py` | `/api/v1/course-enrollments` | `POST /`, `GET /`, `DELETE /{id}` |
| `student_groups.py` | `/api/v1/student-groups` | `POST /`, `GET /`, `GET /{id}`, `PUT /{id}`, `DELETE /{id}` |

### 7.3 Router Aggregator

**File:** `app/routers/v1.py`

```python
api_v1_router = APIRouter(prefix="/api/v1")
api_v1_router.include_router(auth_router)
api_v1_router.include_router(attendance_router)
api_v1_router.include_router(sessions_router)
api_v1_router.include_router(students_router)
api_v1_router.include_router(courses_router)
api_v1_router.include_router(devices_router)
api_v1_router.include_router(users_router)
api_v1_router.include_router(schedules_router)
api_v1_router.include_router(time_slots_router)
api_v1_router.include_router(course_enrollments_router)
api_v1_router.include_router(student_groups_router)
api_v1_router.include_router(faces_router)
```

### 7.4 Main.py Router Registration

```python
# v1 endpoints — production ready
app.include_router(api_v1_router)  # /api/v1/*

# Legacy routers — giữ lại trong thời gian Flutter migrate
app.include_router(auth_router)           # /auth/*
app.include_router(user_router)          # /users/*
app.include_router(student_router)       # /students/*
app.include_router(course_router)         # /courses/*
app.include_router(attendance_router)     # /attendance/*
app.include_router(face_router)          # /face/*
app.include_router(device_router)        # /devices/*
app.include_router(legacy_router)        # /api/* (Flutter legacy)
app.include_router(time_slot_router)    # /time-slots/*
app.include_router(schedule_router)       # /schedules/*
app.include_router(session_router)       # /sessions/*
app.include_router(attendance_new_router) # /attendance/new/*
app.include_router(course_enrollment_router)  # /course-enrollments/*
app.include_router(student_group_router) # /student-groups/*
```

---

## Phase 8: Cleanup & Bug Fixes

| # | File | Issue | Fix |
|---|------|-------|-----|
| 1 | `v1/users.py` | `user_id` dùng 2 lần (path param + Depends) | Đổi thành `target_id` cho path param |
| 2 | `v1/courses.py` | `_uuid.UUID()` nhưng chưa import | Sửa thành `uuid.UUID()` |
| 3 | `SessionRepository` | Thiếu method `create()` | Thêm `create(course_id, ...)` |
| 4 | `UserRepository` | `get_by_id()` nhận UUID nhưng import `str` | Nhận `str \| uuid.UUID`, convert nếu cần |
| 5 | `StudentRepository` | Không filter soft-delete | Thêm `deleted_at IS NULL` |
| 6 | `CourseRepository` | Không filter soft-delete | Thêm `deleted_at IS NULL` |
| 7 | `FaceRepository` | Không filter `is_active` | Thêm `is_active == True` |
| 8 | `user_repository.py` | Dùng `User.is_deleted` không tồn tại | Đổi thành `User.deleted_at.is_(None)` |
| 9 | `session_repository.py` | Dùng `Session.is_deleted` không tồn tại | Đổi thành `Session.deleted_at.is_(None)` |
| 10 | `User model` | `created_by`/`updated_by` không có trong DB | Commented out trong model |
| 11 | `Session model` | `created_by`/`updated_by` không có trong DB | Commented out trong model |

---

## Migration 0014: Refactor Schema Lớn

**File:** `backend/alembic/versions/0014_refactor_schema.py`

### Những gì đã làm:

#### 1. Copy avatar data
- Copy `students.avatar_url` → `users.avatar_url`
- Copy `teachers.avatar_url` → `users.avatar_url`

#### 2. Rename tables
```sql
academic_classes       → student_groups
classes                → courses
classroom_students     → course_enrollments
```

#### 3. Rename columns
```sql
-- courses
teacher_id             → instructor_id
class_name             → course_name

-- sessions
classroom_id           → course_id

-- schedules
classroom_id           → course_id
subject_name           → room

-- devices
classroom_id           → course_id

-- students
academic_class_id      → student_group_id

-- sessions
checkin_start_time     → checkin_window_start
checkin_end_time       → checkin_window_end

-- teachers
employee_code          → teacher_id
```

#### 4. Add new columns
```sql
courses               → course_code
devices               → device_name, mac_address
face_embeddings       → quality_score, captured_at
refresh_tokens        → device_info (JSONB)
sessions              → session_date
```

#### 5. Remove redundant columns
```sql
-- students
avatar_url, has_avatar, attachment_id, is_synced, name

-- teachers
avatar_url
```

#### 6. Enforce strict 1:1 relationships
```sql
-- Make students.user_id NOT NULL UNIQUE
ALTER TABLE students ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE students ADD CONSTRAINT uq_students_user_id UNIQUE (user_id);
```

#### 7. Remove is_deleted columns
```sql
-- Drop is_deleted from all tables, keep only deleted_at
ALTER TABLE {table} DROP COLUMN IF EXISTS is_deleted;
```

#### 8. Update indexes
```sql
DROP INDEX IF EXISTS ix_sessions_classroom_start;
CREATE INDEX ix_sessions_course_start ON sessions(course_id, start_time);
```

---

## Cấu trúc file cuối cùng

```
backend/
├── app/
│   ├── main.py                          # FastAPI app + exception handlers
│   ├── core/
│   │   ├── config.py                    # Settings (15min/7day token)
│   │   ├── database.py                  # AsyncSessionLocal + get_db()
│   │   ├── security.py                  # JWT + refresh token functions
│   │   └── rbac.py                      # @require_role() decorator
│   ├── models/
│   │   ├── _mixins.py                   # SoftDeleteMixin, AuditMixin
│   │   ├── __init__.py                  # All models + aliases
│   │   ├── user.py                      # Đã xóa: attendances, is_deleted
│   │   ├── student.py                   # Đã xóa: job_title, name, avatar_url redundancy
│   │   ├── teacher.py                   # Đã đổi: employee_code → teacher_id
│   │   ├── student_group.py             # Đã đổi tên: academic_classes → student_groups
│   │   ├── course.py                    # Đã đổi: class_name → course_name, teacher_id → instructor_id
│   │   ├── course_enrollment.py         # Đã đổi tên: classroom_students → course_enrollments
│   │   ├── attendance.py                # Xóa user_id, thêm indexes
│   │   ├── face_embedding.py            # Xóa user_id, đổi: embedding_data → embedding
│   │   ├── session.py                   # Đổi: classroom_id → course_id
│   │   ├── schedule.py                  # Đổi: classroom_id → course_id, subject_name → room
│   │   ├── device.py                    # Đổi: classroom_id → course_id, thêm device_name, mac_address
│   │   ├── refresh_token.py             # Mới: RefreshToken model
│   │   ├── schedule.py
│   │   ├── time_slot.py
│   │   └── attendance.py
│   ├── repositories/
│   │   ├── _base.py                     # BaseRepository (soft-delete)
│   │   ├── __init__.py                  # 13 repositories
│   │   ├── user_repository.py           # Cập nhật: deleted_at filter
│   │   ├── student_repository.py        # Cập nhật: deleted_at filter
│   │   ├── course_repository.py         # Mới
│   │   ├── teacher_repository.py        # Mới
│   │   ├── student_group_repository.py  # Mới
│   │   ├── course_enrollment_repository.py  # Mới
│   │   ├── attendance_repository.py      # Refactor: Attendance (not AttendanceRecord)
│   │   ├── face_repository.py           # Cập nhật: is_active filter
│   │   ├── session_repository.py        # Mới + auto-update status
│   │   ├── schedule_repository.py        # Mới
│   │   ├── time_slot_repository.py      # Mới
│   │   ├── course_enrollment_repository.py  # Mới
│   │   ├── student_group_repository.py # Mới
│   │   └── device_repository.py         # Mới
│   ├── services/
│   │   ├── _base.py                     # BaseService
│   │   ├── _authorization.py             # check_course_owner, check_session_owner
│   │   ├── auth_service.py
│   │   ├── user_service.py
│   │   ├── student_service.py
│   │   ├── course_service.py
│   │   ├── attendance_service.py        # Refactor: unified session-based
│   │   ├── face_service.py             # Max-5 FIFO
│   │   ├── anti_cheat_service.py       # Refactor: cleaner validation
│   │   ├── device_service.py           # Device sync + bulk attendance
│   │   ├── audit_service.py           # Structured audit logging
│   │   ├── session_service.py
│   │   ├── schedule_service.py
│   │   ├── time_slot_service.py
│   │   ├── course_enrollment_service.py
│   │   └── student_group_service.py
│   ├── schemas/
│   │   ├── __init__.py                 # Legacy schemas (giữ lại cho Flutter)
│   │   ├── v1/
│   │   │   ├── __init__.py              # v1 re-exports
│   │   │   ├── common.py               # PaginationParams, PaginatedResponse
│   │   │   ├── auth.py                  # LoginRequest, RegisterRequest, TokenResponse...
│   │   │   ├── attendance.py             # AttendanceCreate, AttendanceOut, AttendanceSummary...
│   │   │   ├── device.py                # DeviceSyncResponse, BulkAttendanceRequest...
│   │   │   ├── face.py                # FaceRegisterRequest, FaceStatusResponse...
│   │   │   ├── session.py               # SessionCreate, SessionOut...
│   │   │   ├── course.py              # CourseCreate, CourseOut...
│   │   │   ├── student.py               # StudentCreate, StudentOut...
│   │   │   ├── user.py                  # UserOut, UserList
│   │   │   ├── schedule.py              # ScheduleCreate, ScheduleOut...
│   │   │   ├── time_slot.py             # TimeSlotCreate, TimeSlotOut...
│   │   │   ├── course_enrollment.py     # CourseEnrollmentCreate, ...
│   │   │   └── student_group.py        # StudentGroupCreate, ...
│   │   ├── auth_schema.py
│   │   ├── user_schema.py
│   │   ├── student_schema.py
│   │   ├── course_schema.py
│   │   ├── attendance_schema.py
│   │   ├── attendance_new_schema.py
│   │   ├── face_schema.py
│   │   ├── device_schema.py
│   │   ├── schedule_schema.py
│   │   ├── session_schema.py
│   │   ├── time_slot_schema.py
│   │   ├── course_enrollment_schema.py
│   │   ├── student_group_schema.py
│   │   └── classroom_student_schema.py
│   └── routers/
│       ├── v1.py                        # API v1 aggregator
│       ├── v1/
│       │   ├── auth.py                  # /api/v1/auth
│       │   ├── attendance.py             # /api/v1/attendance
│       │   ├── sessions.py              # /api/v1/sessions
│       │   ├── students.py              # /api/v1/students
│       │   ├── courses.py               # /api/v1/courses
│       │   ├── devices.py              # /api/v1/devices
│       │   ├── faces.py               # /api/v1/students/{id}/face
│       │   ├── users.py                # /api/v1/users
│       │   ├── schedules.py            # /api/v1/schedules
│       │   ├── time_slots.py            # /api/v1/time-slots
│       │   ├── course_enrollments.py    # /api/v1/course-enrollments
│       │   └── student_groups.py        # /api/v1/student-groups
│       ├── auth_router.py               # Legacy /auth
│       ├── user_router.py               # Legacy /users
│       ├── student_router.py           # Legacy /students
│       ├── course_router.py             # Legacy /courses
│       ├── attendance_router.py         # Legacy /attendance
│       ├── attendance_new_router.py     # Legacy /attendance/new
│       ├── face_router.py              # Legacy /face
│       ├── device_router.py            # Legacy /devices
│       ├── legacy_router.py            # Flutter legacy /api/*
│       ├── schedule_router.py           # Legacy /schedules
│       ├── session_router.py           # Legacy /sessions
│       ├── time_slot_router.py         # Legacy /time-slots
│       ├── course_enrollment_router.py  # Legacy /course-enrollments
│       └── student_group_router.py     # Legacy /student-groups
└── alembic/
    └── versions/
        ├── 0001_initial_schema.py
        ├── 0002_add_avatar_url_to_users.py
        ├── 0003_expand_schema.py
        ├── 0004_migrate_attendance_data.py
        ├── 0005_create_academic_classes.py
        ├── 0006_add_academic_class_to_students.py
        ├── 0007_fix_session_timestamps.py
        ├── 0008_add_attendance_fields.py
        ├── 0009_enhance_devices.py
        ├── 0010_add_soft_delete_audit.py
        ├── 0011_unify_attendance_identity.py   # Xóa user_id, thêm indexes
        ├── 0012_add_refresh_tokens_and_device_auth.py  # RefreshToken + device auth
        ├── 0013_data_integrity.py             # UNIQUE, indexes
        ├── 20260320_1718_5e31f594dece_add_student_code_to_students.py
        ├── 20260320_2000_123456789abc_rename_employee_code.py
        └── 0014_refactor_schema.py             # TÁI CẤU TRÚC LỚN
```

---

## Các thay đổi quan trọng (Migration 0014)

### Đã xóa
- `AttendanceRecord` model (không tồn tại, chỉ có `Attendance`)
- `user_id` trong `attendance` table (chỉ dùng `student_id`)
- `user_id` trong `face_embeddings` table (chỉ dùng `student_id`)
- `is_deleted` trong tất cả các bảng (chỉ dùng `deleted_at`)
- Redundant fields trong `students`: `avatar_url`, `has_avatar`, `attachment_id`, `is_synced`, `name`, `job_title`
- `avatar_url` trong `teachers`
- `attendances` relationship trong `User` model

### Đã đổi tên (bảng)
- `academic_classes` → `student_groups`
- `classes` → `courses`
- `classroom_students` → `course_enrollments`

### Đã đổi tên (cột)
- `classes.teacher_id` → `courses.instructor_id`
- `classes.class_name` → `courses.course_name`
- `sessions.classroom_id` → `sessions.course_id`
- `schedules.classroom_id` → `schedules.course_id`
- `devices.classroom_id` → `devices.course_id`
- `schedules.subject_name` → `schedules.room`
- `sessions.checkin_start_time` → `sessions.checkin_window_start`
- `sessions.checkin_end_time` → `sessions.checkin_window_end`
- `teachers.employee_code` → `teachers.teacher_id`
- `face_embeddings.embedding_data` → `face_embeddings.embedding`
- `students.academic_class_id` → `students.student_group_id`

### Đã thêm
- `RefreshToken` model + `refresh_tokens` table
- 12 v1 schemas (`app/schemas/v1/`)
- 12 v1 routers (`app/routers/v1/`) — production-ready endpoints
- `BaseRepository` với soft-delete filtering tự động
- 7 repository mới (course, teacher, student_group, course_enrollment, session, schedule, time_slot, device)
- `AntiCheatService` — anti-cheat validation hoàn chỉnh
- `AttendanceService` (unified) — session-based attendance
- `DeviceService` — device sync + bulk attendance
- `@require_role()` RBAC decorator
- Refresh token flow (15 phút access token, 7 ngày refresh token)
- Global exception handlers cho tất cả loại lỗi
- `device_name`, `mac_address` trong `devices`
- `quality_score`, `captured_at` trong `face_embeddings`
- `device_info` trong `refresh_tokens`
- `session_date`, `checkin_window_start`, `checkin_window_end` trong `sessions`
- `course_code` trong `courses`
- Backward-compat aliases: `Classroom = Course`, `ClassroomStudent = CourseEnrollment`, `AcademicClass = StudentGroup`

---

## Chạy migrations

```bash
cd backend
alembic upgrade head
```

Migrations cần chạy theo thứ tự:
1. `0001` → `0010` — Initial schema + soft delete
2. `0011` — Unify attendance identity (xóa user_id, thêm indexes)
3. `0012` — Refresh tokens + device authentication
4. `0013` — Data integrity (UNIQUE constraints)
5. `20260320_1718_5e31f...` — Add student_code
6. `20260320_2000_abc...` — Rename employee_code → teacher_id
7. `0014` — Refactor schema (đổi tên bảng/cột, xóa trường thừa)

---

## Sau khi Flutter migrate xong

Xóa legacy routers khỏi `app/main.py`:
- `auth_router`, `user_router`, `student_router`, `course_router`
- `attendance_router`, `attendance_new_router`, `face_router`, `device_router`
- `legacy_router`, `schedule_router`, `session_router`
- `time_slot_router`, `course_enrollment_router`, `student_group_router`
