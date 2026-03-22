# Phân Tích Hệ Thống Backend — Face Time Keeping

> **Ngày cập nhật:** 2026-03-21
> **Framework:** FastAPI + SQLAlchemy 2.x (async) + PostgreSQL + Alembic
> **Trạng thái:** Hoàn thành sau Migration 0014

---

## Mục Lục

1. [Tổng Quan Kiến Trúc](#1-tổng-quan-kiến-trúc)
2. [Cấu Trúc Thư Mục](#2-cấu-trúc-thư-mục)
3. [Phân Tích Chi Tiết Từng Module](#3-phân-tích-chi-tiết-từng-module)
4. [Hệ Thống API Endpoint](#4-hệ-thống-api-endpoint)
5. [Hệ Thống Xác Thực & Bảo Mật](#5-hệ-thống-xác-thực--bảo-mật)
6. [Luồng Điểm Danh](#6-luồng-điểm-danh)
7. [Tương Thích Flutter](#7-tương-thích-flutter)
8. [Các Vấn Đề Tiềm Ẩn & Cách Xử Lý](#8-các-vấn-đề-tiềm-ẩn--cách-xử-lý)

---

## 1. Tổng Quan Kiến Trúc

Backend được xây dựng trên **FastAPI** với kiến trúc **3-layer Clean Architecture**:

```
┌─────────────────────────────────────────────────┐
│                  Router Layer                     │
│   (Xử lý HTTP request/response, validation)     │
├─────────────────────────────────────────────────┤
│                  Service Layer                    │
│   (Business logic, anti-cheat, orchestration)    │
├─────────────────────────────────────────────────┤
│                Repository Layer                    │
│   (Database queries, SQLAlchemy ORM)             │
├─────────────────────────────────────────────────┤
│               PostgreSQL Database                │
│          (Async driver: asyncpg)                │
└─────────────────────────────────────────────────┘
```

**Dual API Surface:**
```
┌──────────────────────────────────────────────────────┐
│                   FastAPI Backend                     │
├────────────────────────┬─────────────────────────────┤
│   v1 API (/api/v1/*)   │  Legacy API (/auth, /api/*) │
│   Production-ready     │  Flutter migration pending   │
└────────────────────────┴─────────────────────────────┘
```

**Công nghệ sử dụng:**
- **Framework**: FastAPI (async/await throughout)
- **Database**: PostgreSQL
- **ORM**: SQLAlchemy 2.x (async)
- **Driver**: asyncpg (async PostgreSQL driver)
- **Auth**: JWT (jose library), OAuth2 Bearer Token
- **Password**: bcrypt_sha256 (passlib CryptContext)
- **Validation**: Pydantic v2
- **Migrations**: Alembic (16 migrations)
- **Rate Limiting**: SlowAPI

---

## 2. Cấu Trúc Thư Mục

```
backend/
├── app/
│   ├── main.py                         # FastAPI app, exception handlers, router aggregation
│   ├── dependencies.py                 # get_db, get_current_user dependencies
│   │
│   ├── core/
│   │   ├── config.py                  # Pydantic Settings (env vars)
│   │   ├── database.py                # SQLAlchemy async engine + AsyncSessionLocal + get_db()
│   │   ├── security.py                # JWT (15min access + 7day refresh), bcrypt, OAuth2
│   │   ├── rbac.py                    # @require_role() decorator
│   │   ├── rate_limit.py              # SlowAPI rate limiter
│   │   └── logger.py                  # Logging config + security_logger
│   │
│   ├── models/                        # SQLAlchemy ORM models
│   │   ├── __init__.py                # Exports all models + backward-compat aliases
│   │   ├── _mixins.py                 # SoftDeleteMixin, AuditMixin
│   │   ├── user.py                    # users table
│   │   ├── teacher.py                 # teachers table
│   │   ├── student.py                 # students table (INT PK)
│   │   ├── student_group.py           # student_groups table (đã đổi tên từ academic_classes)
│   │   ├── course.py                  # courses table (đã đổi tên từ classes)
│   │   ├── course_enrollment.py       # course_enrollments table (đã đổi tên)
│   │   ├── time_slot.py               # time_slots table
│   │   ├── schedule.py                # schedules table
│   │   ├── session.py                 # sessions table
│   │   ├── attendance.py              # attendance table
│   │   ├── face_embedding.py          # face_embeddings table
│   │   ├── device.py                  # devices table
│   │   └── refresh_token.py            # refresh_tokens table
│   │
│   ├── schemas/
│   │   ├── __init__.py               # Legacy schema exports
│   │   ├── auth_schema.py            # Legacy: LoginRequest, TokenResponse, UserInfo
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
│   │   ├── student_group_schema.py
│   │   │
│   │   └── v1/                       # v1 schemas (production-ready)
│   │       ├── __init__.py
│   │       ├── common.py             # PaginationParams, PaginatedResponse, ErrorDetail
│   │       ├── auth.py              # LoginRequest, RegisterRequest, TokenResponse, UserInfo
│   │       ├── user.py
│   │       ├── student.py
│   │       ├── course.py
│   │       ├── attendance.py
│   │       ├── device.py            # DeviceSyncResponse, BulkAttendanceRequest/Response
│   │       ├── face.py             # FaceRegisterRequest, FaceStatusResponse, FaceBulkExport
│   │       ├── session.py
│   │       ├── schedule.py
│   │       ├── time_slot.py
│   │       ├── course_enrollment.py
│   │       └── student_group.py
│   │
│   ├── repositories/                 # Database query layer
│   │   ├── __init__.py
│   │   ├── _base.py                # BaseRepository (soft-delete filter tự động)
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
│   ├── services/                    # Business logic
│   │   ├── __init__.py
│   │   ├── _base.py               # BaseService
│   │   ├── _authorization.py       # check_classroom_owner, check_session_owner
│   │   ├── auth_service.py        # Register, login, avatar upload (512px), refresh token
│   │   ├── user_service.py
│   │   ├── student_service.py
│   │   ├── course_service.py
│   │   ├── attendance_service.py   # Unified session-based attendance
│   │   ├── face_service.py        # Face registration (max-5 FIFO), export/import
│   │   ├── device_service.py      # Device sync, bulk attendance
│   │   ├── anti_cheat_service.py  # Session/device/window/duplicate validation
│   │   ├── audit_service.py      # Structured audit logging
│   │   ├── session_service.py
│   │   ├── schedule_service.py
│   │   ├── time_slot_service.py
│   │   ├── course_enrollment_service.py
│   │   └── student_group_service.py
│   │
│   └── routers/
│       ├── __init__.py
│       ├── v1.py                  # api_v1_router aggregator
│       ├── v1/                    # v1 production endpoints
│       │   ├── __init__.py
│       │   ├── auth.py           # /api/v1/auth
│       │   ├── users.py         # /api/v1/users
│       │   ├── students.py      # /api/v1/students
│       │   ├── courses.py       # /api/v1/courses
│       │   ├── attendance.py     # /api/v1/attendance
│       │   ├── devices.py       # /api/v1/devices
│       │   ├── sessions.py      # /api/v1/sessions
│       │   ├── schedules.py     # /api/v1/schedules
│       │   ├── time_slots.py    # /api/v1/time-slots
│       │   ├── course_enrollments.py  # /api/v1/course-enrollments
│       │   ├── student_groups.py # /api/v1/student-groups
│       │   └── faces.py         # /api/v1/faces
│       │
│       └── legacy/               # Legacy endpoints (Flutter migration pending)
│           ├── auth_router.py    # /auth
│           ├── user_router.py    # /users
│           ├── student_router.py # /students
│           ├── course_router.py   # /courses
│           ├── attendance_router.py    # /attendance
│           ├── attendance_new_router.py # /attendance/new
│           ├── face_router.py    # /face
│           ├── device_router.py  # /devices
│           ├── legacy_router.py  # /api (Flutter legacy)
│           ├── schedule_router.py # /schedules
│           ├── session_router.py # /sessions
│           ├── time_slot_router.py # /time-slots
│           ├── course_enrollment_router.py # /course-enrollments
│           └── student_group_router.py # /student-groups
│
└── alembic/
    ├── alembic.ini
    ├── env.py
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
        ├── 0011_unify_attendance_identity.py
        ├── 0012_add_refresh_tokens_and_device_auth.py
        ├── 0013_data_integrity.py
        ├── 20260320_1718_5e31f594dece_add_student_code_to_students.py
        ├── 20260320_2000_123456789abc_rename_employee_code.py
        └── 0014_refactor_schema.py
```

---

## 3. Phân Tích Chi Tiết Từng Module

### 3.1 Models (Mô Hình Dữ Liệu)

Xem chi tiết tại [final_db.md](./final_db.md).

### 3.2 Schemas (Lược Đồ API)

Mỗi module có schema riêng cho request và response, được tổ chức theo pattern:

- **v1 schemas** (`app/schemas/v1/`): Production-ready với Pydantic v2, snake_case
- **Legacy schemas**: Tương thích ngược với Flutter (camelCase envelope `data.*`)

| Schema File | Key Classes |
|------------|------------|
| `v1/auth.py` | `LoginRequest`, `RegisterRequest`, `TokenResponse`, `UserInfo`, `AvatarUploadResponse` |
| `v1/attendance.py` | `AttendanceCreate`, `AttendanceOut`, `AttendanceList`, `AttendanceSummary` |
| `v1/device.py` | `DeviceSyncResponse`, `BulkAttendanceRequest`, `BulkAttendanceResponse` |
| `v1/face.py` | `FaceRegisterRequest`, `FaceStatusResponse`, `FaceBulkExport` |
| `v1/common.py` | `PaginationParams`, `PaginatedResponse`, `ErrorDetail` |

### 3.3 Routers (Bộ Định Tuyến)

#### v1 Routers (Production-ready)

| Router | Prefix | Endpoints |
|--------|--------|-----------|
| `v1/auth.py` | `/api/v1/auth` | Register, Login, Refresh, Me, Avatar, Logout |
| `v1/attendance.py` | `/api/v1/attendance` | Create, Get by Session, Get by Student, Get, Delete, Summary |
| `v1/devices.py` | `/api/v1/devices` | CRUD, Sync, Bulk-attendance |
| `v1/sessions.py` | `/api/v1/sessions` | CRUD, Auto-transition, Summary |
| `v1/courses.py` | `/api/v1/courses` | CRUD + Students management |
| `v1/students.py` | `/api/v1/students` | CRUD |
| `v1/faces.py` | `/api/v1/students/{id}/face` | Register, Status, Export embeddings |
| `v1/users.py` | `/api/v1/users` | List, Get |
| `v1/student_groups.py` | `/api/v1/student-groups` | CRUD |
| `v1/course_enrollments.py` | `/api/v1/course-enrollments` | CRUD |
| `v1/schedules.py` | `/api/v1/schedules` | CRUD |
| `v1/time_slots.py` | `/api/v1/time-slots` | CRUD |

#### Legacy Routers (Flutter migration pending)

| Router | Prefix | Mục đích |
|--------|--------|----------|
| `legacy_router.py` | `/api` | Flutter legacy endpoints |
| `auth_router.py` | `/auth` | Legacy auth |
| `attendance_router.py` | `/attendance` | Legacy attendance |
| `attendance_new_router.py` | `/attendance/new` | Session-based attendance |

### 3.4 Services (Nghiệp Vụ)

| Service | Trách nhiệm |
|---------|-------------|
| `AuthService` | Đăng ký, đăng nhập, avatar upload (resize 512px JPEG), refresh token |
| `AttendanceService` | Unified session-based attendance với anti-cheat |
| `AntiCheatService` | Validate session, device, time window, duplicate |
| `FaceService` | Register face (max-5 FIFO), export/import, status |
| `DeviceService` | Device sync (pull data), bulk attendance (push) |
| `AuditService` | Structured audit logging: attendance_created, face_registered, login/logout |
| `SessionService` | CRUD + auto-transition (scheduled→active→closed) |

### 3.5 Repositories (Truy Vấn DB)

Tất cả repositories mở rộng `BaseRepository`:

```python
class BaseRepository(Generic[ModelT]):
    # Tự động filter: deleted_at IS NULL
    async def get_by_id(id)
    async def list(skip, limit) → (items, total)
    async def count() → int
    async def add(instance)
    async def soft_delete(instance)
```

| Repository | Notable Methods |
|------------|----------------|
| `StudentRepository` | `get_all()` ordered by ID for Flutter compatibility |
| `AttendanceRepository` | `get_by_session()`, `get_by_student()`, `count_by_status()` |
| `FaceRepository` | `replace_for_student()` (atomic FIFO), `get_all_for_course()` (device sync) |
| `SessionRepository` | `auto_update_status()` (scheduled→active, active→closed) |
| `DeviceRepository` | `get_by_code()` (device auth), `get_by_course()` |
| `CourseEnrollmentRepository` | `get_students_with_face_status()` (JOIN students + face_embeddings) |

### 3.6 Core (Cấu Hình Cốt Lõi)

#### Database (`database.py`)
- **AsyncEngine**: `create_async_engine` với `postgresql+asyncpg`
- **Pool**: `pool_size=10`, `max_overflow=20`, `pool_pre_ping=True`
- **Session**: `AsyncSessionLocal` với `expire_on_commit=False`, `autoflush=False`
- **Dependency**: `get_db()` - yields session, auto commit on success, rollback on error

#### Security (`security.py`)
- **Password**: `CryptContext` hỗ trợ `bcrypt_sha256` (ưu tiên) và `bcrypt` (fallback)
- **JWT**: `jose` library, thuật toán `HS256`
- **Access Token**: 15 phút (cấu hình trong config)
- **Refresh Token**: 7 ngày, có thể thu hồi (lưu hashed JTI vào DB)
- **OAuth2**: `OAuth2PasswordBearer` trỏ đến `/auth/login`

#### Config (`config.py`)

| Biến | Mặc định | Mô tả |
|------|----------|-------|
| `DATABASE_URL` | `postgresql+asyncpg://vedura:vedura_pass@db:5432/vedura_db` | PostgreSQL connection string |
| `SECRET_KEY` | `changeme-super-secret-key-please-update-in-production` | Khóa ký JWT (**phải đổi trong production**) |
| `ALGORITHM` | `HS256` | Thuật toán JWT |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `15` | Thời gian hết hạn access token |
| `REFRESH_TOKEN_EXPIRE_DAYS` | `7` | Thời gian hết hạn refresh token |
| `UPLOAD_DIR` | `uploads` | Thư mục lưu file upload |
| `DEBUG` | `False` | SQLAlchemy echo mode |
| `CORS_ORIGINS` | `["*"]` | Allowed CORS origins |

---

## 4. Hệ Thống API Endpoint

### 4.1 v1 API (`/api/v1/`)

#### Authentication (`/api/v1/auth`)
| Method | Path | Auth | Mô tả |
|--------|------|------|-------|
| POST | `/register` | ❌ | Đăng ký tài khoản (teacher/student/admin) |
| POST | `/login` | ❌ | Đăng nhập, nhận JWT access + refresh token |
| POST | `/refresh` | ❌ | Refresh access token bằng refresh token |
| GET | `/me` | ✅ | Lấy thông tin user hiện tại |
| POST | `/avatar` | ✅ | Upload avatar (resize 512px JPEG) |
| POST | `/logout` | ✅ | Logout: thu hồi tất cả refresh tokens |

#### Attendance (`/api/v1/attendance`)
| Method | Path | Auth | Mô tả |
|--------|------|------|-------|
| POST | `/` | ✅ | Tạo điểm danh với anti-cheat |
| GET | `/session/{session_id}` | ✅ | Lấy điểm danh theo phiên (phân trang) |
| GET | `/student/{student_id}` | ✅ | Lấy lịch sử điểm danh SV (phân trang) |
| GET | `/{attendance_id}` | ✅ | Lấy 1 bản ghi điểm danh |
| DELETE | `/{attendance_id}` | ✅ | Xóa mềm điểm danh |
| GET | `/summary/session/{session_id}` | ✅ | Thống kê điểm danh (present/late/absent/rate) |

#### Devices (`/api/v1/devices`)
| Method | Path | Auth | Mô tả |
|--------|------|------|-------|
| POST | `/` | ✅ | Tạo thiết bị |
| GET | `/` | ✅ | Danh sách thiết bị |
| GET | `/{id}` | ✅ | Chi tiết thiết bị |
| PUT | `/{id}` | ✅ | Cập nhật thiết bị |
| DELETE | `/{id}` | ✅ | Xóa mềm thiết bị |
| GET | `/{id}/sync` | ✅ | **Pull**: lấy students + embeddings + sessions cho offline |
| POST | `/bulk-attendance` | ✅ | **Push**: bulk attendance từ offline device |

#### Sessions (`/api/v1/sessions`)
| Method | Path | Auth | Mô tả |
|--------|------|------|-------|
| POST | `/` | ✅ | Tạo phiên điểm danh |
| GET | `/` | ✅ | Danh sách phiên |
| GET | `/{id}` | ✅ | Chi tiết phiên |
| PUT | `/{id}` | ✅ | Cập nhật phiên |
| PATCH | `/{id}/status` | ✅ | Cập nhật trạng thái |
| DELETE | `/{id}` | ✅ | Xóa mềm phiên |
| GET | `/{id}/summary` | ✅ | Thống kê điểm danh |

#### Faces (`/api/v1/students/{id}/face`)
| Method | Path | Auth | Mô tả |
|--------|------|------|-------|
| POST | `/` | ✅ | Đăng ký face embedding (max 5, FIFO) |
| GET | `/face-status` | ✅ | Kiểm tra trạng thái đăng ký |
| GET | `/classrooms/{id}/face-embeddings` | ✅ | Export embeddings cho device sync |

### 4.2 Legacy API (Flutter)

Xem chi tiết tại [backend_implementation_summary.md](./backend_implementation_summary.md).

---

## 5. Hệ Thống Xác Thực & Bảo Mật

### 5.1 JWT Authentication Flow

```
1. User POST /api/v1/auth/login {email, password}
           ↓
2. AuthService xác thực credentials (bcrypt)
           ↓
3. Tạo JWT access_token (HS256, 15 phút) + refresh_token (7 ngày)
           ↓
4. Lưu hashed refresh_token JTI vào refresh_tokens table
           ↓
5. Client lưu token (secure storage)
           ↓
6. Mọi request sau đều gửi: Authorization: Bearer <access_token>
           ↓
7. OAuth2PasswordBearer dependency extract user_id từ token
           ↓
8. Khi access_token hết hạn → POST /api/v1/auth/refresh với refresh_token
```

### 5.2 Refresh Token Flow

```
┌──────────────┐
│   Register    │────▶ Tạo user
│   / Login    │
└──────┬───────┘
       │
       ├──▶ Access Token (15 phút)
       │
       └──▶ Refresh Token (7 ngày) ──▶ Lưu hashed JTI vào DB
                       │
                       ▼
              POST /api/v1/auth/refresh
                       │
                       ▼
              Tạo access token mới + refresh token mới
                       │
                       ▼
              POST /api/v1/auth/logout ──▶ Revoke all tokens
```

### 5.3 RBAC Authorization

```python
@router.get("/admin-panel")
async def admin_panel(
    user = Depends(require_role("admin"))
):
    return {"admin": user}
```

| Role | Quyền |
|------|-------|
| `admin` | Full access |
| `teacher` | Own classrooms, sessions |
| `student` | Own attendance, own face data |

### 5.4 Anti-Cheat Validation

```python
async def create_attendance(session_id, student_id, ...):
    # 1. Session must exist + not soft-deleted
    AntiCheatService.validate_session_exists(session_id)

    # 2. Device must belong to session's course
    AntiCheatService.validate_device_for_session(device_id, session)

    # 3. Check-in must be within [session.start - 30min, session.end]
    AntiCheatService.validate_checkin_window(session, checkin_time)

    # 4. No duplicate attendance per student+session
    AntiCheatService.detect_duplicate(session_id, student_id)

    # 5. Auto-detect "late": checkin_time > session.start_time + 15min

    # 6. Insert attendance record
```

### 5.5 Cơ Chế Bảo Mật

| Cơ chế | Mô tả |
|--------|-------|
| **Password Hashing** | bcrypt_sha256 (ưu tiên), bcrypt (fallback) |
| **JWT Tokens** | HS256, 15 phút access, 7 ngày refresh |
| **Refresh Token Revocation** | Lưu hashed JTI vào DB, có thể revoke từng token hoặc tất cả |
| **Soft Delete** | Tất cả model chính có `deleted_at` (KHÔNG có `is_deleted`) |
| **Audit Logging** | Structured log: attendance_created, face_registered, login/logout |
| **Rate Limiting** | SlowAPI Limiter (configurable) |
| **Global Exception Handlers** | Handle IntegrityError, OperationalError, DataError, generic Exception |

### 5.6 Global Exception Handlers

| Exception | HTTP Status | Message |
|-----------|-------------|---------|
| `RequestValidationError` | 422 | "Request validation failed" |
| `HTTPException` | Giữ nguyên | Giữ nguyên |
| `IntegrityError` (unique) | 409 | "Duplicate entry" |
| `IntegrityError` (FK) | 422 | "Referenced record not found" |
| `OperationalError` | 503 | "Database temporarily unavailable" |
| `DataError` | 422 | "Invalid data" |
| `Exception` (generic) | 500 | "Internal server error" |

---

## 6. Luồng Điểm Danh

### 6.1 Online Flow

```
┌─────────────┐                        ┌─────────────┐
│  Flutter/   │   POST /attendance     │   FastAPI   │
│  Device    │ ──────────────────────▶ │   Backend   │
│            │ ◀────────────────────── │             │
└─────────────┘   { attendance_id }   └─────────────┘
                                            │
                        AntiCheatService.validate_*()
                                            │
                        AttendanceService.create_attendance()
                                            │
                        AuditService.log_attendance_created()
```

### 6.2 Offline-First Device Flow

```
┌─────────────┐                        ┌─────────────┐
│   Device    │  GET /devices/{id}/sync│   FastAPI   │
│  (Offline)  │ ◀──────────────────────│   Backend   │
└─────────────┘   { students[],        └─────────────┘
                    embeddings[],
                    sessions[] }
        │
        │ [Device operates offline,
        │  captures attendance]
        │
        ▼
┌─────────────┐
│  Local DB   │
│  (SQLite)   │
└─────────────┘
        │
        │ [After reconnection]
        │
        ▼
┌─────────────┐  POST /devices/bulk-attendance   ┌─────────────┐
│   Device    │ ───────────────────────────────▶  │   FastAPI   │
│  (Online)   │ ◀─────────────────────────────── │   Backend   │
└─────────────┘   { synced: N, errors: M }       └─────────────┘
```

---

## 7. Tương Thích Flutter

### 7.1 Legacy Endpoints (`/api/*`)

Flutter sử dụng các legacy endpoints trong khi chờ migrate sang v1:

#### Endpoint nhân viên (Employee)
- `GET /api/employee/get_all_employees` → Danh sách employee với envelope `data.employees`
- `POST /api/employee/create` → Tạo 1 employee
- `POST /api/employee/create/batch` → Tạo nhiều employee cùng lúc
- `POST /api/employee/avatars/upload` → Upload batch avatar images

#### Endpoint khuôn mặt
- `GET /api/employee/export/json` → Export tất cả face embeddings (Flutter pull)
- `PUT /api/employee/update/embedding` → Import embeddings từ JSON file (Flutter push)

#### Endpoint điểm danh
- `POST /api/attendance/history/sync_bulk_io` → Bulk sync điểm danh offline

### 7.2 Đặc Điểm Tương Thích

| Vấn đề | Giải pháp |
|---------|-----------|
| Flutter dùng `classId` (camelCase) | Legacy schemas dùng `ClassId` |
| Student PK là INTEGER | Model `Student` dùng `Integer` primary key |
| Face embeddings 128-d vector | Lưu trong JSONB dưới dạng `List[float]` |
| Bulk operations | `batch_create_employees()`, `bulk_sync()` |
| Export/Import face data | `FaceService.export_all()`, `FaceService.import_from_file()` |

### 7.3 Flutter Data Flow

```
┌─────────────────┐     REST API      ┌─────────────────┐
│   Flutter App   │ ←───────────────→  │    FastAPI      │
│   (Face SDK)   │                    │    Backend      │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         │  1. Employee CRUD                   │
         │  2. Face Embedding Register         │
         │  3. Export/Import for offline sync  │
         │  4. Attendance Sync                 │
         ↓                                      ↓
┌─────────────────┐                    ┌─────────────────┐
│   Device Local   │ ←─────────────────→│   PostgreSQL    │
│   (SQLite/Cache) │   Sync offline    │                 │
└─────────────────┘                    └─────────────────┘
```

---

## 8. Các Vấn Đề Tiềm Ẩn & Cách Xử Lý

### 8.1 Đã Xử Lý (Sau Migration 0014)

#### ✅ Import inconsistency (`AttendanceRecord` vs `Attendance`)
- **Trước**: `AttendanceRepository` import `AttendanceRecord` nhưng model chỉ định nghĩa `Attendance`
- **Sau**: Đã xóa `AttendanceRecord`, chỉ dùng `Attendance`

#### ✅ `is_deleted` vs `deleted_at` redundancy
- **Trước**: Nhiều model có cả `is_deleted` và `deleted_at`
- **Sau**: Chỉ dùng `deleted_at` (migration 0014 đã xóa `is_deleted`)

#### ✅ Student model dùng `job_title` cho `academic_class_id`
- **Trước**: Trường `job_title` (String) lưu mã lớp hành chính
- **Sau**: Dùng `student_group_id` (UUID FK) chính thức

#### ✅ Avatar redundancy
- **Trước**: `avatar_url` tồn tại trong `users`, `students`, `teachers`
- **Sau**: Chỉ `users.avatar_url` — single source of truth

#### ✅ Name redundancy
- **Trước**: `students.name` trùng lặp với `users.full_name`
- **Sau**: Xóa `students.name`, dùng computed property `student.name → user.full_name`

#### ✅ Two attendance systems
- **Trước**: Hệ thống cũ và mới song song
- **Sau**: Thống nhất — chỉ còn `Attendance` model với session-based approach

### 8.2 Cần Lưu Ý

#### ⚠️ CORS cho phép tất cả origins
```python
CORS_ORIGINS = ["*"]  # Mặc định
```
**Rủi ro**: Cho phép request từ bất kỳ domain nào.
**Khuyến nghị**: Cấu hình theo môi trường trong `.env`.

#### ⚠️ SECRET_KEY mặc định
```python
SECRET_KEY = "changeme-super-secret-key-please-update-in-production"
```
**Rủi ro**: Nếu không đổi trong `.env`, JWT có thể bị giả mạo.
**Khuyến nghị**: Đổi trong `.env` trước khi deploy.

#### ⚠️ `created_by` / `updated_by` fields
- Model `User` và `Session` có `created_by` / `updated_by` **commented out**
- Model `Student`, `Course`, `StudentGroup`, `Schedule`, `Device` vẫn có
- Kiểm tra database migration có tạo các cột này chưa

#### ⚠️ pgvector cho face embeddings
- Hiện tại dùng JSONB cho embeddings
- **Khuyến nghị**: Chuyển sang pgvector cho production:
```sql
ALTER TABLE face_embeddings ALTER COLUMN embedding TYPE vector(128);
CREATE INDEX ON face_embeddings USING ivfflat (embedding vector_cosine_ops);
```

### 8.3 Checklist Debug

Xem chi tiết tại [handle_error_backend.md](./handle_error_backend.md).

---

## Tổng Kết

| Khía cạnh | Đánh giá |
|-----------|----------|
| **Kiến trúc** | ✅ Tốt — Clean 3-layer, async throughout |
| **Bảo mật** | ⚠️ Cần cải thiện — CORS `*`, SECRET_KEY mặc định |
| **Code quality** | ✅ Tốt sau Migration 0014 — đã xóa redundant fields |
| **Tương thích Flutter** | ✅ Tốt — Legacy endpoints + INT PK cho students |
| **Mở rộng** | ✅ Tốt — Indexes đầy đủ, soft-delete, audit |
| **Anti-cheat** | ✅ Đã implement — Device, time window, duplicate detection |
| **Refactor hoàn tất** | ✅ Migration 0014 — đổi tên bảng/cột, xóa trường thừa |

**Điểm mạnh:**
- Kiến trúc clean, dễ mở rộng
- Hỗ trợ async PostgreSQL tốt
- Anti-cheat service cho attendance
- Refresh token có thể thu hồi
- Legacy endpoints cho Flutter
- Soft delete nhất quán (`deleted_at` only)
- Single source of truth cho avatar và name

**Cần cải thiện (production):**
1. Đổi `SECRET_KEY` trong `.env`
2. Cấu hình `CORS_ORIGINS` theo môi trường
3. Thêm rate limit cho `/auth/login` (chống brute-force)
4. Xem xét pgvector cho face embeddings (performance)
5. Verify `created_by`/`updated_by` columns tồn tại trong DB
