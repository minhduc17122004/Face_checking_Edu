# Backend Implementation Report — Face Time Keeping System

> **Date:** 2026-03-19  
> **Status:** Phase 1–8 Hoàn thành  
> **Framework:** FastAPI + SQLAlchemy 2.x (async) + PostgreSQL + Alembic

---

## Tổng quan kiến trúc

```
┌─────────────────────────────────────────────────────────────┐
│                        FastAPI App                           │
├─────────────────────────────────────────────────────────────┤
│  Routers (v1)          │  Legacy Routers (đợi Flutter migrate)│
│  /api/v1/*             │  /auth, /students, /classes...     │
├─────────────────────────────────────────────────────────────┤
│                    Service Layer                            │
│  AttendanceService, AuthService, AntiCheatService...       │
├─────────────────────────────────────────────────────────────┤
│                  Repository Layer                           │
│  BaseRepository (soft-delete), 11 repositories             │
├─────────────────────────────────────────────────────────────┤
│                SQLAlchemy 2.x Async ORM                    │
├─────────────────────────────────────────────────────────────┤
│                    PostgreSQL                               │
│  Alembic Migrations (0011, 0012)                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Mixins & Models — Đồng nhất hóa tất cả models

### 1.1 Tạo Mixins

**File:** `app/models/_mixins.py`

```python
class SoftDeleteMixin:
    is_deleted: Mapped[bool] = Boolean(default=False, nullable=False)
    deleted_at: Mapped[Optional[datetime]] = DateTime(timezone=True, nullable=True)

class AuditMixin:
    created_by: Mapped[Optional[str]] = None
    updated_by: Mapped[Optional[str]] = None
```

### 1.2 Cập nhật Models

| File | Thay đổi |
|------|-----------|
| `attendance.py` | **Xóa `user_id`** (đồng nhất chỉ dùng `student_id`). Thêm `CheckConstraint` cho `status IN ('present', 'late', 'absent')`. Thêm index `ix_attendance_session_student` và `ix_attendance_checkin_time` |
| `face_embedding.py` | **Xóa `user_id`** (chỉ dùng `student_id`). Thêm index `ix_face_embeddings_student_id` |
| `student.py` | **Xóa `job_title`** (trường bị lạm dụng sai mục đích). Chỉ dùng `academic_class_id`. Xóa `attendance_records` (legacy AttendanceRecord) |
| `classroom.py` | Xóa `attendance_records` (legacy). Thêm index `ix_sessions_classroom_start` |
| `session.py` | Thêm index `ix_sessions_classroom_start` |
| `classroom_student.py` | Thêm composite index `ix_classroom_students_class_student` |
| `user.py` | Xóa `attendances` relationship (sau khi xóa `user_id` khỏi Attendance) |
| `__init__.py` | **Sửa bug nghiêm trọng:** xóa `AttendanceRecord` (model không tồn tại). Thêm `RefreshToken`, `_mixins` |

### 1.3 Bug đã fix

- **`AttendanceRecord` không tồn tại:** `attendance_repository.py` import `AttendanceRecord` nhưng model chỉ định nghĩa `Attendance`. Đã refactor toàn bộ để dùng `Attendance`.

---

## Phase 2: Database Migration 0011

**File:** `backend/alembic/versions/0011_unify_attendance_identity.py`

```sql
-- 1. Xóa user_id khỏi attendance
ALTER TABLE attendance DROP COLUMN IF EXISTS user_id;

-- 2. Xóa user_id khỏi face_embeddings
ALTER TABLE face_embeddings DROP COLUMN IF EXISTS user_id;

-- 3. Indexes mới
CREATE INDEX ix_attendance_session_student ON attendance (session_id, student_id);
CREATE INDEX ix_attendance_checkin_time ON attendance (checkin_time);
CREATE INDEX ix_sessions_classroom_start ON sessions (classroom_id, start_time);
CREATE INDEX ix_classroom_students_class_student ON classroom_students (classroom_id, student_id);
```

---

## Phase 3: Repository Layer — Nền tảng dữ liệu

### 3.1 Base Repository

**File:** `app/repositories/_base.py`

```python
class BaseRepository(Generic[ModelT]):
    # Tự động lọc is_deleted == False trên tất cả queries
    # Cung cấp: get_by_id(), list(), count(), add(), soft_delete()
```

### 3.2 Các Repository đã tạo/cập nhật

| Repository | File | Mô tả |
|-----------|------|--------|
| `BaseRepository` | `_base.py` | Base class với soft-delete filter |
| `AttendanceRepository` | `attendance_repository.py` | **Refactor hoàn toàn:** dùng `Attendance` thay vì `AttendanceRecord`. Hỗ trợ session-based attendance, soft-delete |
| `SessionRepository` | `session_repository.py` | Mới: CRUD sessions, lọc theo classroom/date/status |
| `ScheduleRepository` | `schedule_repository.py` | Mới: CRUD schedules, lọc theo classroom/day |
| `TimeSlotRepository` | `time_slot_repository.py` | Mới: reference data (không soft-delete) |
| `ClassroomStudentRepository` | `classroom_student_repository.py` | Mới: enrollment management, `find_enrollment()`, `count_by_classroom()` |
| `AcademicClassRepository` | `academic_class_repository.py` | Mới: CRUD academic classes, `get_by_code()` |
| `DeviceRepository` | `device_repository.py` | Mới: CRUD devices, `get_by_code()`, `get_active()` |
| `UserRepository` | `user_repository.py` | **Cập nhật:** thêm soft-delete filter, nhận `str \| UUID` |
| `StudentRepository` | `student_repository.py` | **Cập nhật:** thêm soft-delete filter |
| `ClassroomRepository` | `classroom_repository.py` | **Cập nhật:** thêm soft-delete filter |
| `FaceRepository` | `face_repository.py` | **Cập nhật:** thêm filter `is_active == True` |

### 3.3 Thiết kế Repository

```
BaseRepository (generic)
├── get_by_id(id)        → tự động filter is_deleted
├── list(skip, limit)     → trả về (items, total)
├── count()              → đếm bản ghi active
├── add(instance)        → flush
└── soft_delete(instance) → is_deleted=True, deleted_at=now

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
        → Device phải thuộc cùng classroom với session

    validate_checkin_window(session_id, checkin_time)
        → Kiểm tra session.status == "active"
        → checkin phải trong khoảng checkin_start_time → checkin_end_time

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
|-----------|-----------|---------|
| `RequestValidationError` | 422 | "Request validation failed" |
| `HTTPException` | Tự giữ nguyên | Tự giữ nguyên |
| `IntegrityError` (unique) | 409 | "Duplicate entry" |
| `IntegrityError` (FK) | 422 | "Referenced record not found" |
| `ForeignKeyViolation` | 422 | "Referenced record not found" |
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
| `classroom.py` | `ClassCreate`, `ClassOut`, `ClassList` |
| `device.py` | `DeviceCreate`, `DeviceUpdate`, `DeviceResponse` |
| `user.py` | `UserOut`, `UserList` |
| `schedule.py` | `ScheduleCreate`, `ScheduleOut`, `ScheduleWithTimeSlot`, `ScheduleList` |
| `time_slot.py` | `TimeSlotCreate`, `TimeSlotOut`, `TimeSlotList` |
| `classroom_student.py` | `ClassroomStudentCreate`, `ClassroomStudentOut`, `ClassroomStudentList` |
| `academic_class.py` | `AcademicClassCreate`, `AcademicClassUpdate`, `AcademicClassOut`, `AcademicClassList` |

### 7.2 Router Files (`app/routers/v1/`)

| Router | Prefix | Endpoints |
|--------|--------|-----------|
| `auth.py` | `/api/v1/auth` | `POST /register`, `POST /login`, `POST /refresh`, `GET /me`, `POST /avatar`, `POST /logout` |
| `attendance.py` | `/api/v1/attendance` | `POST /`, `GET /session/{id}`, `GET /student/{id}`, `GET /{id}`, `DELETE /{id}`, `GET /summary/session/{id}` |
| `sessions.py` | `/api/v1/sessions` | `POST /`, `GET /`, `GET /{id}`, `PATCH /{id}`, `DELETE /{id}`, `GET /{id}/summary` |
| `students.py` | `/api/v1/students` | `POST /`, `GET /`, `GET /{id}` |
| `classrooms.py` | `/api/v1/classrooms` | `POST /`, `GET /?mine=`, `GET /{id}`, `DELETE /{id}` |
| `devices.py` | `/api/v1/devices` | `POST /`, `GET /{id}`, `PATCH /{id}` |
| `users.py` | `/api/v1/users` | `GET /`, `GET /{id}` |
| `schedules.py` | `/api/v1/schedules` | `POST /`, `GET /`, `GET /{id}`, `DELETE /{id}` |
| `time_slots.py` | `/api/v1/time-slots` | `POST /`, `GET /`, `GET /{id}` |
| `classroom_students.py` | `/api/v1/classroom-students` | `POST /`, `GET /`, `DELETE /{id}` |
| `academic_classes.py` | `/api/v1/academic-classes` | `POST /`, `GET /`, `GET /{id}`, `PATCH /{id}`, `DELETE /{id}` |

### 7.3 Router Aggregator

**File:** `app/routers/v1.py`

```python
api_v1_router = APIRouter(prefix="/api/v1")
api_v1_router.include_router(auth_router)
api_v1_router.include_router(attendance_router)
api_v1_router.include_router(sessions_router)
api_v1_router.include_router(students_router)
api_v1_router.include_router(classrooms_router)
api_v1_router.include_router(devices_router)
api_v1_router.include_router(users_router)
api_v1_router.include_router(schedules_router)
api_v1_router.include_router(time_slots_router)
api_v1_router.include_router(classroom_students_router)
api_v1_router.include_router(academic_classes_router)
```

### 7.4 Main.py Router Registration

```python
# v1 endpoints — production ready
app.include_router(api_v1_router)  # /api/v1/*

# Legacy routers — giữ lại trong thời gian Flutter migrate
app.include_router(auth_router)           # /auth/*
app.include_router(user_router)          # /users/*
app.include_router(student_router)       # /students/*
app.include_router(classroom_router)     # /classes/*
app.include_router(attendance_router)     # /attendance/*
app.include_router(face_router)          # /face/*
app.include_router(device_router)        # /devices/*
app.include_router(legacy_router)        # /api/* (Flutter legacy)
app.include_router(time_slot_router)     # /time-slots/*
app.include_router(schedule_router)       # /schedules/*
app.include_router(session_router)       # /sessions/*
app.include_router(attendance_new_router) # /attendance/new/*
app.include_router(academic_class_router) # /academic-classes/*
```

---

## Phase 8: Cleanup & Bug Fixes

| # | File | Issue | Fix |
|---|------|-------|-----|
| 1 | `v1/users.py` | `user_id` dùng 2 lần (path param + Depends) | Đổi thành `target_id` cho path param |
| 2 | `v1/classrooms.py` | `_uuid.UUID()` nhưng chưa import | Sửa thành `uuid.UUID()` |
| 3 | `SessionRepository` | Thiếu method `create()` | Thêm `create(classroom_id, ...)` |
| 4 | `UserRepository` | `get_by_id()` nhận UUID nhưng import `str` | Nhận `str \| uuid.UUID`, convert nếu cần |
| 5 | `StudentRepository` | Không filter soft-delete | Thêm `is_deleted == False` |
| 6 | `ClassroomRepository` | Không filter soft-delete | Thêm `is_deleted == False` |
| 7 | `FaceRepository` | Không filter `is_active` | Thêm `is_active == True` |

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
│   │   ├── __init__.py                  # Tất cả models + fix AttendanceRecord
│   │   ├── user.py                      # Đã xóa attendances relationship
│   │   ├── student.py                   # Đã xóa job_title, legacy attendance
│   │   ├── classroom.py                 # Đã xóa attendance_records
│   │   ├── attendance.py                # Xóa user_id, thêm indexes
│   │   ├── face_embedding.py            # Xóa user_id, thêm index
│   │   ├── session.py                   # Thêm composite index
│   │   ├── classroom_student.py         # Thêm composite index
│   │   ├── refresh_token.py             # Mới: RefreshToken model
│   │   ├── schedule.py
│   │   ├── device.py
│   │   ├── time_slot.py
│   │   ├── teacher.py
│   │   └── academic_class.py
│   ├── repositories/
│   │   ├── _base.py                     # BaseRepository (soft-delete)
│   │   ├── __init__.py                  # 12 repositories
│   │   ├── user_repository.py           # Cập nhật: soft-delete
│   │   ├── student_repository.py        # Cập nhật: soft-delete
│   │   ├── classroom_repository.py      # Cập nhật: soft-delete
│   │   ├── attendance_repository.py      # Refactor: Attendance (not AttendanceRecord)
│   │   ├── face_repository.py           # Cập nhật: is_active filter
│   │   ├── session_repository.py        # Mới
│   │   ├── schedule_repository.py        # Mới
│   │   ├── time_slot_repository.py      # Mới
│   │   ├── classroom_student_repository.py  # Mới
│   │   ├── academic_class_repository.py # Mới
│   │   └── device_repository.py         # Mới
│   ├── services/
│   │   ├── _base.py                     # BaseService
│   │   ├── __init__.py
│   │   ├── auth_service.py
│   │   ├── user_service.py
│   │   ├── student_service.py
│   │   ├── classroom_service.py
│   │   ├── attendance_service.py        # Refactor: unified session-based
│   │   ├── face_service.py
│   │   └── anti_cheat_service.py       # Refactor: cleaner validation
│   ├── schemas/
│   │   ├── __init__.py                 # Legacy schemas (giữ lại cho Flutter)
│   │   ├── v1/
│   │   │   ├── __init__.py              # v1 re-exports
│   │   │   ├── auth.py                   # LoginRequest, RegisterRequest, TokenResponse...
│   │   │   ├── attendance.py             # AttendanceCreate, AttendanceOut, AttendanceSummary...
│   │   │   ├── session.py               # SessionCreate, SessionOut...
│   │   │   ├── student.py               # StudentCreate, StudentOut...
│   │   │   ├── classroom.py             # ClassCreate, ClassOut...
│   │   │   ├── device.py                # DeviceCreate, DeviceResponse...
│   │   │   ├── user.py                  # UserOut, UserList
│   │   │   ├── schedule.py              # ScheduleCreate, ScheduleOut...
│   │   │   ├── time_slot.py             # TimeSlotCreate, TimeSlotOut...
│   │   │   ├── classroom_student.py     # ClassroomStudentCreate, ...
│   │   │   └── academic_class.py        # AcademicClassCreate, ...
│   │   ├── auth_schema.py
│   │   ├── attendance_schema.py
│   │   ├── attendance_new_schema.py
│   │   ├── face_schema.py
│   │   ├── classroom_schema.py
│   │   ├── student_schema.py
│   │   ├── user_schema.py
│   │   ├── schedule_schema.py
│   │   ├── session_schema.py
│   │   ├── time_slot_schema.py
│   │   ├── classroom_student_schema.py
│   │   ├── academic_class_schema.py
│   │   └── device_schema.py
│   └── routers/
│       ├── v1.py                        # API v1 aggregator
│       ├── v1/
│       │   ├── auth.py                  # /api/v1/auth
│       │   ├── attendance.py             # /api/v1/attendance
│       │   ├── sessions.py              # /api/v1/sessions
│       │   ├── students.py              # /api/v1/students
│       │   ├── classrooms.py            # /api/v1/classrooms
│       │   ├── devices.py              # /api/v1/devices
│       │   ├── users.py                # /api/v1/users
│       │   ├── schedules.py            # /api/v1/schedules
│       │   ├── time_slots.py            # /api/v1/time-slots
│       │   ├── classroom_students.py    # /api/v1/classroom-students
│       │   └── academic_classes.py      # /api/v1/academic-classes
│       ├── auth_router.py               # Legacy /auth
│       ├── user_router.py               # Legacy /users
│       ├── student_router.py           # Legacy /students
│       ├── classroom_router.py          # Legacy /classes
│       ├── attendance_router.py         # Legacy /attendance
│       ├── attendance_new_router.py     # Legacy /attendance/new
│       ├── face_router.py              # Legacy /face
│       ├── device_router.py            # Legacy /devices
│       ├── legacy_router.py            # Flutter legacy /api/*
│       ├── schedule_router.py           # Legacy /schedules
│       ├── session_router.py           # Legacy /sessions
│       ├── time_slot_router.py         # Legacy /time-slots
│       ├── classroom_student_router.py  # Legacy /classroom-students
│       └── academic_class_router.py    # Legacy /academic-classes
└── alembic/
    └── versions/
        ├── 0011_unify_attendance_identity.py   # Xóa user_id, thêm indexes
        └── 0012_add_refresh_tokens_and_device_auth.py  # RefreshToken + device auth
```

---

## Các thay đổi quan trọng

### Đã xóa
- `AttendanceRecord` model (không tồn tại, chỉ có `Attendance`)
- `user_id` trong `attendance` table (chỉ dùng `student_id`)
- `user_id` trong `face_embeddings` table (chỉ dùng `student_id`)
- `job_title` trong `student` (trường bị lạm dụng sai mục đích)
- `attendance_records` relationship trong `classroom` (legacy)
- `attendance_records` relationship trong `student` (legacy)

### Đã thêm
- `RefreshToken` model + `refresh_tokens` table
- 11 v1 schemas (`app/schemas/v1/`)
- 11 v1 routers (`app/routers/v1/`) — production-ready endpoints
- `BaseRepository` với soft-delete filtering tự động
- 6 repository mới (session, schedule, time_slot, classroom_student, academic_class, device)
- `AntiCheatService` — anti-cheat validation hoàn chỉnh
- `AttendanceService` (unified) — session-based attendance
- `@require_role()` RBAC decorator
- Refresh token flow (15 phút access token, 7 ngày refresh token)
- 6 composite indexes cho performance
- Global exception handlers cho tất cả loại lỗi

---

## Chạy migrations

```bash
cd backend
alembic upgrade head
```

Migrations cần chạy theo thứ tự:
1. `0011` — Unify attendance identity (xóa user_id, thêm indexes)
2. `0012` — Refresh tokens + device authentication

---

## Sau khi Flutter migrate xong

Xóa legacy routers khỏi `app/main.py`:
- `auth_router`, `user_router`, `student_router`, `classroom_router`
- `attendance_router`, `attendance_new_router`, `face_router`, `device_router`
- `legacy_router`, `schedule_router`, `session_router`
- `time_slot_router`, `classroom_student_router`, `academic_class_router`
