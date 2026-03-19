# Backend Implementation Summary - Face Time Keeping System

> **Vedura AI** - Face Recognition Attendance System
> FastAPI Backend | PostgreSQL + SQLAlchemy (async) | JWT Authentication

---

## 1. Architecture Overview

### Tech Stack
- **Framework**: FastAPI (async)
- **Database**: PostgreSQL with SQLAlchemy ORM (async)
- **Authentication**: JWT (15min access + 7day refresh tokens, revocable)
- **Migrations**: Alembic with 13 migrations
- **Authorization**: RBAC (admin / teacher / student roles)
- **Rate Limiting**: SlowAPI
- **Face Recognition**: 128-dimensional face embeddings stored as `JSONB`

### Dual API Design
The backend exposes **two parallel API surfaces**:
1. **v1 API** (`/api/v1/*`) — Production-ready, session-based, standardized
2. **Legacy API** (`/api/*`) — Flutter migration compatible, student-ID based

---

## 2. Core Models

### `users` — Central Authentication Table
```python
- id: UUID PK
- email: str (unique, indexed)
- password_hash: str
- full_name: str
- role: Enum (admin, teacher, student)
- avatar_url: str | None
- is_active: bool (default True)
- created_at, updated_at
```

### `students` — Student Profiles (Flutter-Compatible Integer PK)
```python
- id: int PK (AUTOINCREMENT — compatible with Flutter int)
- user_id: UUID FK (nullable, 1:1 with User)
- name: str
- pin: str | None (4-digit attendance PIN)
- email: str | None
- phone: str | None
- academic_class_id: UUID FK (nullable)
- avatar_url: str | None
- has_avatar: bool
- created_at, updated_at, is_deleted, deleted_at
```
> All attendance and face embedding records reference `student.id` (integer), NOT `user_id`.

### `classes` — Classrooms / Course Sections
```python
- id: UUID PK
- class_name: str
- subject: str | None
- description: str | None
- teacher_id: UUID FK → users.id
- device_id: UUID FK → devices.id (nullable)
- time_slot_id: int FK → time_slots.id (nullable)
- is_active: bool
- created_at, updated_at, is_deleted, deleted_at
```

### `sessions` — Attendance Sessions
```python
- id: UUID PK
- classroom_id: UUID FK → classes.id
- session_name: str
- start_time: datetime
- end_time: datetime
- status: Enum (scheduled → active → closed)
- attendance_mode: Enum (face / pin / both)
- created_by: UUID FK → users.id
- created_at, updated_at
```
- Auto-transitions: `scheduled → active` when `start_time` is reached, `active → closed` when `end_time` is passed (triggered on app startup + on each check-in)

### `attendance` — Unified Attendance Records
```python
- id: UUID PK
- session_id: UUID FK → sessions.id
- student_id: int FK → students.id
- checkin_time: datetime (device-reported time)
- sync_time: datetime (server-received time)
- status: Enum (present, late, absent, excused)
- confidence: float | None (face match confidence)
- device_id: UUID FK → devices.id | None
- latitude, longitude: float | None
- ip_address: str | None
- is_edited: bool
- created_at
```
> **Unique Constraint**: `(session_id, student_id)` — prevents duplicate check-ins per session.

### `face_embeddings` — Face Recognition Data
```python
- id: UUID PK
- student_id: int FK → students.id
- embedding_data: JSONB (list of 128 floats)
- is_active: bool (default True)
- created_at
```
- **Max-5 FIFO**: Each student can have up to 5 embeddings; exceeding 5 auto-deletes the oldest (`created_at ASC`).
- **Partial Index**: `ix_face_embeddings_active_student` on `(student_id) WHERE is_active = true`

### `devices` — Physical Attendance Kiosks
```python
- id: UUID PK
- device_code: str (unique)
- device_name: str
- room: str | None
- classroom_id: UUID FK → classes.id | None
- is_active: bool
- anti_cheat_enabled: bool
- allowed_latitude, allowed_longitude, allowed_radius: float | None
- created_at, updated_at, is_deleted, deleted_at
```

### `academic_classes` — Administrative Classes
```python
- id: UUID PK
- code: str (unique, e.g. "D21_CNTT_A")
- name: str (e.g. "Khoa CNTT - Khóa 2021 - CNTT A")
- faculty: str | None
- course_year: int | None
- advisor_id: UUID FK → users.id | None
- created_at, updated_at, is_deleted, deleted_at
```

### `classroom_students` — Many-to-Many Enrollment
```python
- id: UUID PK
- classroom_id: UUID FK → classes.id
- student_id: int FK → students.id
- enrolled_at: datetime
- is_active: bool
```
> Enables student enrollment in multiple classrooms.

### `schedules` — Weekly Class Schedule
```python
- id: UUID PK
- classroom_id: UUID FK → classes.id
- day_of_week: int (0=Monday ... 6=Sunday)
- time_slot_id: int FK → time_slots.id
```

### `time_slots` — Global Period Definitions
```python
- id: int PK
- period_number: int
- start_time: time
- end_time: time
```

### `refresh_tokens` — Revocable JWT Refresh Tokens
```python
- id: UUID PK
- user_id: UUID FK → users.id
- token_jti: str (hashed JTI)
- expires_at: datetime
- revoked: bool
```

---

## 3. Repositories

All repositories extend `BaseRepository` which provides:
- Soft-delete filtering (`is_deleted = false`)
- `get_by_id()`, `list()`, `count()`, `soft_delete()`

### Key Repository Methods

| Repository | Notable Methods |
|-----------|----------------|
| `student_repository.py` | `get_all()` ordered by ID for Flutter compatibility |
| `attendance_repository.py` | `get_by_session()`, `get_by_student()`, `count_by_status()` |
| `face_repository.py` | `replace_for_student()` (atomic delete+insert), `get_all_for_classroom()` (device sync), `get_students_with_embeddings()` |
| `session_repository.py` | `auto_update_status()` (scheduled→active, active→closed), `get_active_sessions_needing_update()` |
| `device_repository.py` | `get_by_code()` (device auth), `get_by_classroom()` |
| `classroom_student_repository.py` | `get_students_with_face_status()` (JOIN students + face_embeddings) |
| `academic_class_repository.py` | `get_by_code()` |

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
2. `AntiCheatService.validate_device_for_session()` — device must match classroom
3. `AntiCheatService.validate_checkin_window()` — must be within [session.start - 30min, session.end]
4. `AntiCheatService.detect_duplicate()` — no existing attendance for same student+session
5. Auto-transition session: `scheduled → active` if `start_time` has passed
6. Auto-detect `late`: `checkin_time > session.start_time + 15min`
7. Insert attendance record
8. `AuditService.log_attendance_created()`

### `face_service.py` — Face Registration
```python
async def register_face(student_id, embedding, device_id=None) → FaceEmbeddingOut
async def get_face_status(student_id) → bool, int
async def export_for_classroom(classroom_id) → FaceBulkExport
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
| GET | `/classrooms/{id}/face-embeddings` | Export embeddings for device sync |

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

#### Classrooms `/api/v1/classrooms`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Create classroom |
| GET | `/` | List my classrooms |
| GET | `/{id}` | Get classroom |
| PUT | `/{id}` | Update classroom (owner only) |
| DELETE | `/{id}` | Soft-delete classroom |
| GET | `/{id}/students` | **List enrolled students with face status** |
| POST | `/{id}/students/{student_id}` | **Enroll student** (ownership + duplicate check) |
| DELETE | `/{id}/students/{student_id}` | **Unenroll student** (ownership check) |

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

#### Academic Classes `/api/v1/academic-classes`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Create academic class |
| GET | `/` | List (paginated, filterable) |
| GET | `/{id}` | Get by ID |
| PUT | `/{id}` | Update |
| DELETE | `/{id}` | Soft-delete |

#### Schedules `/api/v1/schedules`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Create schedule |
| GET | `/` | List (filterable by classroom) |
| GET | `/{id}` | Get schedule |
| PUT | `/{id}` | Update |
| DELETE | `/{id}` | Delete |

#### Time Slots `/api/v1/time-slots`
Full CRUD for time period definitions.

---

## 6. Authorization & Security

### `_authorization.py` — Ownership Validation
```python
check_classroom_owner(classroom, user_id: str)    # 403 if not teacher
check_session_owner(session, user_id: str)      # 403 if not classroom's teacher
check_user_in_classroom(db, user_id, classroom_id)  # via classroom_students
```

### RBAC Roles (`core/rbac.py`)
- **admin**: Full access
- **teacher**: Own classrooms, own sessions
- **student**: Own attendance, own face data

### Anti-Cheat Validation
1. Device must be registered and active
2. Device must belong to the session's classroom
3. Check-in must be within window: `[session.start - 30min, session.end]`
4. No duplicate attendance per student+session

---

## 7. Database Migrations (Alembic)

| # | Migration | Key Changes |
|---|----------|-------------|
| 0001 | Initial Schema | users, teachers, students, classes, face_embeddings, attendance_records |
| 0002 | Add Avatar | avatar_url → users |
| 0003 | Expand Schema | Additional fields and tables |
| 0004 | Migrate Attendance | Data migration |
| 0005 | Academic Classes | academic_classes table |
| 0006 | Student Class Link | academic_class_id → students |
| 0007 | Fix Session Timestamps | Session timing fixes |
| 0008 | Attendance Fields | Additional attendance fields |
| 0009 | Enhance Devices | Anti-cheat fields, room, location |
| 0010 | Soft Delete + Audit | is_deleted, deleted_at, created_by, updated_by |
| 0011 | **Unify Attendance Identity** | New attendance table with student_id only (no user_id) |
| 0012 | Refresh Tokens + Device Auth | refresh_tokens table, device_code |
| 0013 | **Data Integrity** | UNIQUE(session_id, student_id), indexes |

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
       │  2. POST /api/v1/attendance/bulk           │
       │  → { records: [{session_id, student_id,    │
       │       checkin_time, status, confidence}] } │
       │  ← { synced: N, errors: M, results: [] }   │
       │                                            │
```

### Sync Response Schema
```python
DeviceSyncResponse:
  students: list[SyncStudentItem]      # Enrolled students in device's classroom
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

### 3. JSONB Face Embeddings
Face embeddings stored as `JSONB` (list of 128 floats) rather than array column.
Allows easy serialization and filtering while maintaining query performance via partial index.

### 4. Max-5 FIFO Face Registration
Each student can store up to 5 face embeddings. When exceeded, the oldest (`created_at ASC`) is evicted.
This provides redundancy (multiple angles/expressions) while bounding storage.

### 5. Session Auto-Transition
Sessions automatically transition `scheduled → active` (when `start_time` is reached) and
`active → closed` (when `end_time` is passed). This is triggered on app startup and on each check-in,
ensuring the session status is always current.

### 6. Soft Delete Throughout
All major entities have `is_deleted` / `deleted_at` fields with repository-level automatic filtering.
This preserves referential integrity for audit purposes.

### 7. Dual Timestamps on Attendance
- `checkin_time`: Device-reported time (supports offline operation)
- `sync_time`: Server-received time (authoritative server timestamp)

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
│       └── 0013_data_integrity.py
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
│   │   ├── __init__.py            # Model exports
│   │   ├── _mixins.py              # SoftDeleteMixin, AuditMixin
│   │   ├── user.py
│   │   ├── teacher.py
│   │   ├── student.py
│   │   ├── classroom.py
│   │   ├── session.py
│   │   ├── attendance.py
│   │   ├── face_embedding.py
│   │   ├── device.py
│   │   ├── academic_class.py
│   │   ├── refresh_token.py
│   │   ├── schedule.py
│   │   ├── time_slot.py
│   │   └── classroom_student.py
│   │
│   ├── repositories/
│   │   ├── __init__.py
│   │   ├── _base.py                # BaseRepository (soft-delete, CRUD)
│   │   ├── user_repository.py
│   │   ├── student_repository.py
│   │   ├── classroom_repository.py
│   │   ├── attendance_repository.py
│   │   ├── face_repository.py
│   │   ├── session_repository.py
│   │   ├── device_repository.py
│   │   ├── schedule_repository.py
│   │   ├── time_slot_repository.py
│   │   ├── classroom_student_repository.py
│   │   └── academic_class_repository.py
│   │
│   ├── services/
│   │   ├── __init__.py            # Service exports
│   │   ├── _base.py               # BaseService
│   │   ├── _authorization.py       # check_classroom_owner, check_session_owner
│   │   ├── auth_service.py
│   │   ├── user_service.py
│   │   ├── student_service.py
│   │   ├── classroom_service.py
│   │   ├── attendance_service.py
│   │   ├── face_service.py
│   │   ├── anti_cheat_service.py
│   │   ├── device_service.py
│   │   ├── audit_service.py
│   │   ├── schedule_service.py
│   │   ├── time_slot_service.py
│   │   └── academic_class_service.py
│   │
│   ├── schemas/
│   │   ├── __init__.py            # Legacy schema exports
│   │   ├── auth_schema.py
│   │   ├── user_schema.py
│   │   ├── student_schema.py
│   │   ├── classroom_schema.py
│   │   ├── attendance_schema.py
│   │   ├── attendance_new_schema.py
│   │   ├── face_schema.py
│   │   ├── session_schema.py
│   │   ├── device_schema.py
│   │   ├── schedule_schema.py
│   │   ├── time_slot_schema.py
│   │   ├── classroom_student_schema.py
│   │   ├── academic_class_schema.py
│   │   │
│   │   └── v1/
│   │       ├── __init__.py        # v1 schema exports
│   │       ├── common.py          # PaginationParams, PaginatedResponse, ErrorDetail
│   │       ├── auth.py
│   │       ├── user.py
│   │       ├── student.py
│   │       ├── classroom.py       # ClassroomStudentDetail, ClassroomStudentListResponse
│   │       ├── attendance.py
│   │       ├── session.py
│   │       ├── device.py          # DeviceSyncResponse, BulkAttendanceRequest/Response
│   │       ├── face.py            # FaceRegisterRequest, FaceStatusResponse, FaceBulkExport
│   │       ├── schedule.py
│   │       ├── time_slot.py
│   │       ├── classroom_student.py
│   │       └── academic_class.py
│   │
│   └── routers/
│       ├── __init__.py
│       ├── auth_router.py          # Legacy /auth
│       ├── user_router.py          # Legacy /users
│       ├── student_router.py       # Legacy /students
│       ├── classroom_router.py     # Legacy /classes
│       ├── attendance_router.py    # Legacy /attendance
│       ├── attendance_new_router.py # Legacy /attendance/new
│       ├── face_router.py          # Legacy /face
│       ├── device_router.py        # Legacy /devices
│       ├── schedule_router.py      # Legacy /schedules
│       ├── session_router.py       # Legacy /sessions
│       ├── time_slot_router.py     # Legacy /time-slots
│       ├── classroom_student_router.py  # Legacy /classroom-students
│       ├── academic_class_router.py     # Legacy /academic-classes
│       ├── legacy_router.py        # /api (Flutter legacy)
│       │
│       └── v1/
│           ├── __init__.py        # Aggregates all v1 routers
│           ├── auth.py
│           ├── users.py
│           ├── students.py
│           ├── classrooms.py      # + students with face status
│           ├── attendance.py
│           ├── faces.py           # Face registration + device export
│           ├── devices.py         # sync + bulk-attendance
│           ├── sessions.py
│           ├── schedules.py
│           ├── time_slots.py
│           ├── classroom_students.py
│           └── academic_classes.py
│
├── requirements.txt
├── alembic.ini
└── run.py
```
