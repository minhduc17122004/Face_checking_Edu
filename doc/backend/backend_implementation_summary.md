# Backend Implementation Summary - Face Time Keeping System

> **Ngày cập nhật:** 2026-03-21
> **Vedura AI** - Face Recognition Attendance System
> **Framework:** FastAPI + SQLAlchemy 2.x (async) + PostgreSQL + Alembic
> **Trạng thái:** Hoàn thành sau Migration 0014

---

## 1. Architecture Overview

### Tech Stack
- **Framework**: FastAPI (async)
- **Database**: PostgreSQL with SQLAlchemy ORM (async)
- **Authentication**: JWT (15min access + 7day refresh tokens, revocable)
- **Migrations**: Alembic with 16 migrations (0001 → 0014)
- **Authorization**: RBAC (admin / teacher / student roles)
- **Rate Limiting**: SlowAPI
- **Face Recognition**: 128-dimensional face embeddings stored as `JSON`

### Dual API Design
The backend exposes **two parallel API surfaces**:
1. **v1 API** (`/api/v1/*`) — Production-ready, session-based, standardized
2. **Legacy API** (`/api/*`, `/auth/*`, etc.) — Flutter migration compatible, student-ID based

---

## 2. Core Models (13 tables after migration 0014)

### 2.1 Identity Models

#### `users` — Central Authentication Table
```python
- id: UUID PK (indexed)
- email: str (unique, indexed)
- password_hash: str
- full_name: str
- role: Enum (admin, teacher, student)
- avatar_url: str | None  ← Single source of truth
- deleted_at: datetime | None  ← Soft delete (ONLY deleted_at, NO is_deleted)
- created_at, updated_at
```
**Relationships:** 1:1 Teacher, 1:1 Student, 1:N Course, 1:N StudentGroup, 1:N RefreshToken

#### `students` — Student Profiles (Flutter-Compatible Integer PK)
```python
- id: int PK (AUTOINCREMENT — compatible with Flutter int)
- user_id: UUID FK (UNIQUE, NOT NULL, 1:1 with User)
- student_code: str (unique, indexed)  ← MSSV
- pin: str | None (4-digit attendance PIN)
- student_group_id: UUID FK (nullable, links to administrative group)
- deleted_at: datetime | None
- created_at, updated_at, created_by, updated_by
```
> All attendance and face embedding records reference `student.id` (integer), NOT `user_id`.

#### `teachers` — Teacher Profiles
```python
- id: int PK (AUTOINCREMENT)
- user_id: UUID FK (UNIQUE, NOT NULL, 1:1 with User)
- teacher_id: str (unique)  ← Mã cán bộ (đã đổi từ employee_code)
- phone: str | None
- department: str | None
- deleted_at: datetime | None
- created_at, updated_at
```

#### `student_groups` — Administrative Classes (Lớp chủ quản)
```python
- id: UUID PK
- code: str (unique, e.g. "48K22")
- name: str | None
- faculty: str | None
- course_year: str | None (e.g. "K22")
- advisor_id: UUID FK → users.id | None
- deleted_at: datetime | None
- created_at, updated_at, created_by, updated_by
```

### 2.2 Course Models

#### `courses` — Course Sections / Course Offerings
```python
- id: UUID PK
- course_name: str (đã đổi từ class_name)
- subject: str | None
- course_code: str | None (mã lớp học phần)
- instructor_id: UUID FK → users.id (đã đổi từ teacher_id)
- deleted_at: datetime | None
- created_at, updated_at, created_by, updated_by
```

#### `course_enrollments` — Student Course Registration
```python
- id: UUID PK
- course_id: UUID FK → courses.id
- student_id: int FK → students.id
- enrolled_at: datetime
- UNIQUE(course_id, student_id)
```

#### `schedules` — Weekly Class Schedule
```python
- id: UUID PK
- course_id: UUID FK → courses.id (đã đổi từ classroom_id)
- day_of_week: int (1-7)
- time_slot_id: int FK → time_slots.id
- room: str | None (đã đổi từ subject_name)
- deleted_at: datetime | None
- created_at, updated_at, created_by, updated_by
- UNIQUE(course_id, day_of_week, time_slot_id)
```

#### `time_slots` — Global Period Definitions
```python
- id: int PK (AUTOINCREMENT)
- period_number: int (unique)
- start_time: time
- end_time: time
- created_at
- CHECK (start_time < end_time)
```

### 2.3 Attendance Models

#### `sessions` — Attendance Sessions
```python
- id: UUID PK
- course_id: UUID FK → courses.id (đã đổi từ classroom_id)
- schedule_id: UUID FK → schedules.id | None
- session_date: DATE (NOT NULL)
- start_time: TIMESTAMPTZ
- end_time: TIMESTAMPTZ | None
- checkin_window_start: TIMESTAMPTZ | None (đã đổi từ checkin_start_time)
- checkin_window_end: TIMESTAMPTZ | None (đã đổi từ checkin_end_time)
- status: Enum (scheduled → active → closed)
- deleted_at: datetime | None
- created_at, updated_at
```
> Auto-transitions: `scheduled → active` when `start_time` is reached, `active → closed` when `end_time` is passed.

#### `attendance` — Unified Attendance Records
```python
- id: UUID PK
- session_id: UUID FK → sessions.id
- student_id: int FK → students.id  ← Only student_id, NO user_id (unified identity)
- checkin_time: TIMESTAMPTZ (device-reported time)
- sync_time: TIMESTAMPTZ (server-received time)
- status: Enum (present, late, absent)
- confidence: float | None (face match confidence)
- device_id: UUID FK → devices.id | None
- deleted_at: datetime | None
- created_at
- UNIQUE(session_id, student_id)
```

### 2.4 Face & Device Models

#### `face_embeddings` — Face Recognition Data
```python
- id: UUID PK
- student_id: int FK → students.id  ← Only student_id, NO user_id
- embedding: JSON (list of 128 floats)
- is_active: bool (default True, indexed)
- quality_score: float | None (0.0-1.0)
- device_id: UUID FK → devices.id | None
- captured_at: TIMESTAMPTZ
- created_at, updated_at, deleted_at
```
> **Max-5 FIFO**: Each student can have up to 5 embeddings; exceeding 5 auto-deletes the oldest.

#### `devices` — Physical Attendance Kiosks
```python
- id: UUID PK
- device_code: str (unique)
- device_name: str | None
- room: str | None
- device_type: str (default "tablet")
- is_active: bool
- ip_address: str | None
- mac_address: str | None
- course_id: UUID FK → courses.id | None (đã đổi từ classroom_id)
- last_active_at: TIMESTAMPTZ | None
- deleted_at: datetime | None
- created_at, updated_at, created_by, updated_by
```

#### `refresh_tokens` — Revocable JWT Refresh Tokens
```python
- id: UUID PK
- user_id: UUID FK → users.id
- token_jti: str (hashed JTI, unique, indexed)
- device_id: str | None
- device_info: JSONB | None (browser, OS, etc.)
- expires_at: TIMESTAMPTZ
- revoked: bool (default False)
- created_at
```

---

## 3. Repositories

All repositories extend `BaseRepository` which provides:
- Soft-delete filtering (`deleted_at IS NULL`)
- `get_by_id()`, `list()`, `count()`, `soft_delete()`

### Key Repository Methods

| Repository | Notable Methods |
|-----------|----------------|
| `student_repository.py` | `get_all()` ordered by ID for Flutter compatibility |
| `attendance_repository.py` | `get_by_session()`, `get_by_student()`, `count_by_status()` |
| `face_repository.py` | `replace_for_student()` (atomic delete+insert), `get_all_for_course()` (device sync), `get_students_with_embeddings()` |
| `session_repository.py` | `auto_update_status()` (scheduled→active, active→closed), `get_active_sessions_needing_update()` |
| `device_repository.py` | `get_by_code()` (device auth), `get_by_course()` |
| `course_enrollment_repository.py` | `get_students_with_face_status()` (JOIN students + face_embeddings) |

---

## 4. Services

### `attendance_service.py` — Core Attendance Logic
```python
async def create_attendance(
    session_id, student_id, checkin_time, confidence,
    device_id=None, latitude=None, longitude=None, ip_address=None
) → AttendanceCreate
```
**Steps:**
1. `AntiCheatService.validate_session_exists()` — session must exist
2. `AntiCheatService.validate_device_for_session()` — device must match course
3. `AntiCheatService.validate_checkin_window()` — must be within window
4. `AntiCheatService.detect_duplicate()` — no existing attendance for same student+session
5. Auto-transition session: `scheduled → active` if `start_time` has passed
6. Auto-detect `late`: `checkin_time > session.start_time + 15min`
7. Insert attendance record
8. `AuditService.log_attendance_created()`

### `face_service.py` — Face Registration
```python
async def register_face(student_id, embedding, device_id=None) → FaceEmbeddingOut
async def get_face_status(student_id) → bool, int
async def export_for_course(course_id) → FaceBulkExport
async def export_all_for_student(student_id) → list[FaceDataOut]
async def import_faces(student_id, embeddings: list[list[float]]) → int
async def delete_all_faces(student_id) → int
```
**Max-5 FIFO Logic:**
1. Count existing active embeddings for student
2. If count ≥ 5: delete oldest by `created_at ASC`
3. Insert new embedding with `is_active = True`

### `anti_cheat_service.py` — Device & Time Validation
```python
validate_session_exists(session_id)
validate_device_for_session(device_id, session)
validate_checkin_window(session, checkin_time, device_time)
detect_duplicate(db, session_id, student_id)
```

### `device_service.py` — Device Sync
```python
async def sync_data(device_id) → DeviceSyncResponse
    # Returns enrolled students + active embeddings + today's session

async def bulk_attendance(req: BulkAttendanceRequest) → BulkAttendanceResponse
    # Validates device, runs anti-cheat per record, creates attendance in batch
```

### `audit_service.py` — Structured Audit Logging
Logs to `audit` logger with structured extra fields:
- `attendance_created`: attendance_id, student_id, session_id, device_id
- `face_registered`: student_id, embedding_count, device_id
- `device_sync`: device_id, student_count, embedding_count
- `bulk_attendance`: device_id, record_count, synced_count, error_count
- `login` / `logout`: user_id, ip_address

### `auth_service.py` — Authentication
- JWT generation (15min access + 7day refresh)
- Password hashing (bcrypt)
- Avatar upload (resize to 512x512 JPEG)
- Refresh token creation with revocation support
- `@require_role()` RBAC decorator integration

---

## 5. API Endpoints

### v1 API (`/api/v1/`)

#### Authentication `/api/v1/auth`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/register` | Register new user |
| POST | `/login` | Login, returns access + refresh tokens |
| POST | `/refresh` | Refresh access token |
| POST | `/logout` | Revoke refresh token |
| GET | `/me` | Get current user info |
| POST | `/avatar` | Upload avatar (512px JPEG) |

#### Attendance `/api/v1/attendance`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Check-in (with anti-cheat) |
| GET | `/` | List attendance (paginated) |
| GET | `/session/{id}` | Get by session (paginated) |
| GET | `/student/{id}` | Get by student (paginated) |
| GET | `/summary/session/{id}` | Get session summary (counts by status) |
| DELETE | `/{id}` | Remove attendance record |

#### Face `/api/v1/students/{id}/face`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Register face embedding (max 5, FIFO) |
| GET | `/face-status` | Check face registration status |
| GET | `/courses/{id}/face-embeddings` | Export embeddings for device sync |

#### Devices `/api/v1/devices`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Register device |
| GET | `/` | List devices |
| GET | `/{id}` | Get device |
| PUT | `/{id}` | Update device |
| DELETE | `/{id}` | Soft-delete device |
| GET | `/{id}/sync` | **Pull** data for offline operation |
| POST | `/bulk-attendance` | **Push** bulk attendance from device |

#### Courses `/api/v1/courses`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Create course |
| GET | `/` | List courses |
| GET | `/{id}` | Get course |
| PUT | `/{id}` | Update course |
| DELETE | `/{id}` | Soft-delete course |
| GET | `/{id}/students` | **List enrolled students with face status** |
| POST | `/{id}/students/{student_id}` | **Enroll student** |
| DELETE | `/{id}/students/{student_id}` | **Unenroll student** |

#### Sessions `/api/v1/sessions`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Create session |
| GET | `/` | List sessions |
| GET | `/{id}` | Get session |
| PUT | `/{id}` | Update session |
| PATCH | `/{id}/status` | Update session status |
| DELETE | `/{id}` | Soft-delete session |
| GET | `/{id}/summary` | Get session attendance summary |

#### Students `/api/v1/students`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Create student |
| GET | `/` | List students (paginated) |
| GET | `/{id}` | Get student |

#### Student Groups `/api/v1/student-groups`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Create student group |
| GET | `/` | List (paginated, filterable) |
| GET | `/{id}` | Get by ID |
| PUT | `/{id}` | Update |
| DELETE | `/{id}` | Soft-delete |

#### Course Enrollments `/api/v1/course-enrollments`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Create enrollment |
| GET | `/` | List (filterable) |
| DELETE | `/{id}` | Delete enrollment |

#### Schedules `/api/v1/schedules`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Create schedule |
| GET | `/` | List (filterable by course) |
| GET | `/{id}` | Get schedule |
| PUT | `/{id}` | Update |
| DELETE | `/{id}` | Delete |

#### Time Slots `/api/v1/time-slots`
Full CRUD for time period definitions.

---

## 6. Authorization & Security

### `_authorization.py` — Ownership Validation
```python
check_course_owner(course, user_id: str)    # 403 if not instructor
check_session_owner(session, user_id: str)  # 403 if not course's instructor
check_user_in_course(db, user_id, course_id)  # via course_enrollments
```

### RBAC Roles (`core/rbac.py`)
- **admin**: Full access
- **teacher**: Own courses, own sessions
- **student**: Own attendance, own face data

### Anti-Cheat Validation
1. Device must be registered and active
2. Device must belong to the session's course
3. Check-in must be within window: `[session.start - 30min, session.end]`
4. No duplicate attendance per student+session

---

## 7. Database Migrations (Alembic)

| # | Migration | Key Changes |
|---|----------|-------------|
| 0001 | Initial Schema | users, teachers, students, classes, face_embeddings, attendance_records |
| 0002 | Add Avatar | avatar_url → users |
| 0003 | Expand Schema | time_slots, classroom_students, schedules, sessions, attendance, devices |
| 0004 | Migrate Attendance | Data migration |
| 0005 | Academic Classes | academic_classes table |
| 0006 | Student Class Link | academic_class_id → students |
| 0007 | Fix Session Timestamps | Session timing fixes |
| 0008 | Attendance Fields | Additional attendance fields |
| 0009 | Enhance Devices | Anti-cheat fields, room, location |
| 0010 | Soft Delete + Audit | deleted_at, created_by, updated_by |
| 0011 | **Unify Attendance Identity** | Xóa user_id khỏi attendance & face_embeddings |
| 0012 | Refresh Tokens + Device Auth | refresh_tokens table, device_code |
| 0013 | Data Integrity | UNIQUE(session_id, student_id), indexes |
| 5e31f59 | Add student_code | Thêm student_code → students |
| abcdef12 | Rename employee_code | employee_code → teacher_id |
| 0014 | **Refactor Schema** | Đổi tên bảng/cột, xóa trường thừa, enforce 1:1 |

---

## 8. Device Sync Flow

### Offline-First Device Architecture

```
┌─────────────┐                              ┌─────────────┐
│   Device    │                              │   Server    │
│  (Kiosk)    │                              │  FastAPI    │
└──────┬──────┘                              └──────┬──────┘
       │                                            │
       │  1. GET /api/v1/devices/{id}/sync          │
       │  ← { students[], embeddings[], sessions[] }│
       │                                            │
       │  [Device operates offline]                 │
       │                                            │
       │  2. POST /api/v1/devices/bulk-attendance   │
       │  → { records: [{session_id, student_id,    │
       │       checkin_time, status, confidence}] } │
       │  ← { synced: N, errors: M, results: [] }   │
       │                                            │
```

### Sync Response Schema
```python
DeviceSyncResponse:
  students: list[SyncStudentItem]      # Enrolled students in device's course
  embeddings: list[SyncEmbeddingItem]   # Active face embeddings (is_active=True)
  sessions: list[SyncSessionItem]       # Today's + future sessions
  last_sync_at: datetime
```

### Bulk Attendance Response
```python
BulkAttendanceResponse:
  synced: int           # Successfully created
  errors: int           # Failed (anti-cheat rejection)
  results: list[BulkResultItem]  # Per-record outcome
```

---

## 9. Key Design Decisions

### 1. Integer Student IDs
Student PKs use `AUTOINCREMENT int` instead of UUID for Flutter compatibility.
All foreign keys (attendance, face_embeddings) reference `students.id` (int), not `user_id`.

### 2. Unified Attendance Identity
Migration 0011 replaced dual `user_id/student_id` identity with sole `student_id`.
This simplifies the entire data model: one identity across all attendance and face records.

### 3. JSON Face Embeddings
Face embeddings stored as `JSON` (list of 128 floats) rather than array column.
Allows easy serialization. For production, consider pgvector extension.

### 4. Max-5 FIFO Face Registration
Each student can store up to 5 face embeddings. When exceeded, the oldest (`created_at ASC`) is evicted.
This provides redundancy (multiple angles/expressions) while bounding storage.

### 5. Session Auto-Transition
Sessions automatically transition `scheduled → active` (when `start_time` is reached) and
`active → closed` (when `end_time` is passed). Triggered on app startup and on each check-in.

### 6. Soft Delete — deleted_at Only
All major entities have `deleted_at` field only (NO `is_deleted` field).
Repository-level automatic filtering on `deleted_at IS NULL`.

### 7. Dual Timestamps on Attendance
- `checkin_time`: Device-reported time (supports offline operation)
- `sync_time`: Server-received time (authoritative server timestamp)

### 8. Single Source of Truth for Avatar
After migration 0014, `avatar_url` only exists in `users` table.
`Student` and `Teacher` models use computed properties to derive avatar from their linked `User`.

---

## 10. File Inventory

```
backend/
├── alembic/
│   ├── alembic.ini
│   ├── env.py
│   └── versions/
│       ├── 0001_initial_schema.py
│       ├── 0002_add_avatar_url_to_users.py
│       ├── 0003_expand_schema.py
│       ├── 0004_migrate_attendance_data.py
│       ├── 0005_create_academic_classes.py
│       ├── 0006_add_academic_class_to_students.py
│       ├── 0007_fix_session_timestamps.py
│       ├── 0008_add_attendance_fields.py
│       ├── 0009_enhance_devices.py
│       ├── 0010_add_soft_delete_audit.py
│       ├── 0011_unify_attendance_identity.py
│       ├── 0012_add_refresh_tokens_and_device_auth.py
│       ├── 0013_data_integrity.py
│       ├── 20260320_1718_5e31f594dece_add_student_code_to_students.py
│       ├── 20260320_2000_123456789abc_rename_employee_code.py
│       └── 0014_refactor_schema.py
│
├── app/
│   ├── __init__.py
│   ├── main.py                    # FastAPI app, startup events, router aggregation
│   ├── dependencies.py           # get_db, get_current_user dependencies
│   │
│   ├── core/
│   │   ├── config.py              # Settings (DB, JWT, upload paths, CORS)
│   │   ├── database.py            # Async SQLAlchemy engine, session
│   │   ├── security.py            # JWT, password hashing, OAuth2
│   │   ├── logger.py              # Logging config
│   │   ├── rate_limit.py          # SlowAPI rate limiter
│   │   └── rbac.py                 # @require_role() decorator
│   │
│   ├── models/
│   │   ├── __init__.py            # Model exports + backward-compat aliases
│   │   ├── _mixins.py              # SoftDeleteMixin, AuditMixin
│   │   ├── user.py
│   │   ├── teacher.py
│   │   ├── student.py              # INT PK
│   │   ├── student_group.py        # đổi tên từ academic_class
│   │   ├── course.py              # đổi tên từ classroom
│   │   ├── course_enrollment.py   # đổi tên từ classroom_student
│   │   ├── time_slot.py
│   │   ├── schedule.py
│   │   ├── session.py
│   │   ├── attendance.py
│   │   ├── face_embedding.py
│   │   ├── device.py
│   │   └── refresh_token.py
│   │
│   ├── repositories/
│   │   ├── __init__.py
│   │   ├── _base.py                # BaseRepository (soft-delete, CRUD)
│   │   ├── user_repository.py
│   │   ├── student_repository.py
│   │   ├── teacher_repository.py
│   │   ├── course_repository.py
│   │   ├── student_group_repository.py
│   │   ├── course_enrollment_repository.py
│   │   ├── attendance_repository.py
│   │   ├── face_repository.py
│   │   ├── device_repository.py
│   │   ├── session_repository.py
│   │   ├── schedule_repository.py
│   │   └── time_slot_repository.py
│   │
│   ├── services/
│   │   ├── __init__.py            # Service exports
│   │   ├── _base.py               # BaseService
│   │   ├── _authorization.py       # check_course_owner, check_session_owner
│   │   ├── auth_service.py
│   │   ├── user_service.py
│   │   ├── student_service.py
│   │   ├── course_service.py
│   │   ├── attendance_service.py   # Unified session-based
│   │   ├── face_service.py         # Max-5 FIFO registration
│   │   ├── anti_cheat_service.py
│   │   ├── device_service.py       # sync + bulk-attendance
│   │   ├── audit_service.py
│   │   ├── session_service.py
│   │   ├── schedule_service.py
│   │   ├── time_slot_service.py
│   │   ├── course_enrollment_service.py
│   │   └── student_group_service.py
│   │
│   ├── schemas/
│   │   ├── __init__.py            # Legacy schema exports
│   │   ├── auth_schema.py          # LoginRequest, TokenResponse, UserInfo
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
│   │   ├── classroom_student_schema.py
│   │   ├── course_enrollment_schema.py
│   │   └── student_group_schema.py
│   │
│   └── routers/
│       ├── __init__.py
│       ├── v1.py                  # api_v1_router aggregator
│       ├── v1/
│       │   ├── __init__.py
│       │   ├── auth.py            # /api/v1/auth
│       │   ├── users.py           # /api/v1/users
│       │   ├── students.py       # /api/v1/students
│       │   ├── courses.py        # /api/v1/courses
│       │   ├── attendance.py      # /api/v1/attendance
│       │   ├── devices.py         # /api/v1/devices (sync + bulk)
│       │   ├── faces.py          # /api/v1/students/{id}/face
│       │   ├── sessions.py       # /api/v1/sessions
│       │   ├── schedules.py      # /api/v1/schedules
│       │   ├── time_slots.py     # /api/v1/time-slots
│       │   ├── course_enrollments.py  # /api/v1/course-enrollments
│       │   └── student_groups.py  # /api/v1/student-groups
│       │
│       ├── auth_router.py          # Legacy /auth
│       ├── user_router.py          # Legacy /users
│       ├── student_router.py       # Legacy /students
│       ├── course_router.py        # Legacy /courses
│       ├── attendance_router.py    # Legacy /attendance
│       ├── attendance_new_router.py # Legacy /attendance/new
│       ├── face_router.py          # Legacy /face
│       ├── device_router.py        # Legacy /devices
│       ├── schedule_router.py      # Legacy /schedules
│       ├── session_router.py       # Legacy /sessions
│       ├── time_slot_router.py     # Legacy /time-slots
│       ├── course_enrollment_router.py  # Legacy /course-enrollments
│       ├── student_group_router.py # Legacy /student-groups
│       └── legacy_router.py        # /api (Flutter legacy)
│
├── requirements.txt
├── alembic.ini
└── run.py
```
