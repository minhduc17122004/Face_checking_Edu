# Phân Tích Hệ Thống Backend - Face Time Keeping

> **Ngày phân tích:** 19/03/2026  
> **Người thực hiện:** AI Assistant  
> **Trạng thái:** Hoàn thành

---

## Mục Lục

1. [Tổng Quan Kiến Trúc](#1-tổng-quan-kiến-trúc)
2. [Cấu Trúc Thư Mục](#2-cấu-trúc-thư-mục)
3. [Phân Tích Chi Tiết Từng Module](#3-phân-tích-chi-tiết-từng-module)
   - 3.1 Models (Mô Hình Dữ Liệu)
   - 3.2 Schemas (Lược Đồ API)
   - 3.3 Routers (Bộ Định Tuyến)
   - 3.4 Services (Nghiệp Vụ)
   - 3.5 Repositories (Truy Vấn DB)
   - 3.6 Core (Cấu Hình Cốt Lõi)
4. [Hệ Thống API Endpoint](#4-hệ-thống-api-endpoint)
5. [Hệ Thống Xác Thực & Bảo Mật](#5-hệ-thống-xác-thực--bảo-mật)
6. [Hai Hệ Thống Điểm Danh Song Song](#6-hai-hệ-thống-điểm-danh-song-song)
7. [Tương Thích Flutter](#7-tương-thích-flutter)
8. [Các Vấn Đề Tiềm Ẩn](#8-các-vấn-đề-tiềm-ẩn)
9. [Đề Xuất Cải Thiện](#9-đề-xuất-cải-thiện)

---

## 1. Tổng Quan Kiến Trúc

Backend được xây dựng trên **FastAPI** với kiến trúc **3-layer Clean Architecture**:

```
┌─────────────────────────────────────────────────┐
│                    Router Layer                  │
│    (Xử lý HTTP request/response, validation)    │
├─────────────────────────────────────────────────┤
│                   Service Layer                  │
│    (Business logic, anti-cheat, orchestration)  │
├─────────────────────────────────────────────────┤
│                 Repository Layer                 │
│    (Database queries, SQLAlchemy ORM)            │
├─────────────────────────────────────────────────┤
│               PostgreSQL Database               │
│         (Async driver: asyncpg)                 │
└─────────────────────────────────────────────────┘
```

**Công nghệ sử dụng:**
- **Framework**: FastAPI (async/await throughout)
- **Database**: PostgreSQL
- **ORM**: SQLAlchemy 2.x (async)
- **Driver**: asyncpg (async PostgreSQL driver)
- **Auth**: JWT (jose library), OAuth2 Bearer Token
- **Password**: bcrypt (passlib CryptContext)
- **Validation**: Pydantic v2
- **Migrations**: Alembic

---

## 2. Cấu Trúc Thư Mục

```
backend/
├── app/
│   ├── main.py                    # Entry point - FastAPI app initialization
│   ├── core/                     # Cấu hình cốt lõi
│   │   ├── config.py             # Pydantic Settings (env vars)
│   │   ├── database.py           # SQLAlchemy async engine + session
│   │   ├── security.py           # JWT, password hashing, OAuth2
│   │   ├── rate_limit.py         # SlowAPI rate limiter
│   │   └── logger.py             # Security event logging
│   ├── models/                   # SQLAlchemy ORM models
│   │   ├── user.py
│   │   ├── teacher.py
│   │   ├── student.py
│   │   ├── classroom.py
│   │   ├── attendance.py          # ⚠️ Hệ thống điểm danh mới (session-based)
│   │   ├── face_embedding.py
│   │   ├── device.py
│   │   ├── time_slot.py
│   │   ├── schedule.py
│   │   ├── session.py
│   │   ├── classroom_student.py
│   │   └── academic_class.py
│   ├── schemas/                  # Pydantic schemas (API request/response)
│   │   ├── auth_schema.py
│   │   ├── user_schema.py
│   │   ├── student_schema.py
│   │   ├── classroom_schema.py
│   │   ├── attendance_schema.py
│   │   ├── face_schema.py
│   │   ├── device_schema.py
│   │   ├── attendance_new_schema.py
│   │   ├── time_slot_schema.py
│   │   ├── classroom_student_schema.py
│   │   ├── schedule_schema.py
│   │   ├── session_schema.py
│   │   └── academic_class_schema.py
│   ├── routers/                  # API route handlers
│   │   ├── auth_router.py
│   │   ├── user_router.py
│   │   ├── student_router.py
│   │   ├── classroom_router.py
│   │   ├── attendance_router.py
│   │   ├── face_router.py
│   │   ├── device_router.py
│   │   ├── legacy_router.py       # ⚠️ Flutter legacy endpoints
│   │   ├── time_slot_router.py
│   │   ├── classroom_student_router.py
│   │   ├── schedule_router.py
│   │   ├── session_router.py
│   │   ├── attendance_new_router.py
│   │   └── academic_class_router.py
│   ├── services/                 # Business logic
│   │   ├── auth_service.py
│   │   ├── user_service.py
│   │   ├── student_service.py
│   │   ├── classroom_service.py
│   │   ├── attendance_service.py
│   │   ├── face_service.py
│   │   └── anti_cheat_service.py
│   └── repositories/            # Database query layer
│       ├── user_repository.py
│       ├── student_repository.py
│       ├── classroom_repository.py
│       ├── attendance_repository.py
│       └── face_repository.py
└── alembic/                     # Database migrations
    └── versions/
```

---

## 3. Phân Tích Chi Tiết Từng Module

### 3.1 Models (Mô Hình Dữ Liệu)

#### 3.1.1 User Model (`user.py`)
**Bảng:** `users`

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | UUID | Khóa chính |
| `email` | String(255), unique | Email đăng nhập |
| `password_hash` | String(255) | Mật khẩu đã băm (bcrypt) |
| `full_name` | String(255) | Họ tên đầy đủ |
| `role` | Enum | `teacher` / `student` / `admin` |
| `avatar_url` | String(512), nullable | URL ảnh đại diện |
| `is_deleted` | Boolean | Soft delete flag |
| `created_by` | UUID, nullable | Người tạo |
| `updated_by` | UUID, nullable | Người cập nhật |
| `created_at` | DateTime | Thời gian tạo |
| `updated_at` | DateTime | Thời gian cập nhật |

**Quan hệ:**
- 1:1 với `Teacher` (giáo viên)
- 1:1 với `Student` (sinh viên - tài khoản liên kết)
- 1:N với `Classroom` (lớp học mà giáo viên sở hữu)
- 1:N với `FaceEmbedding` (khuôn mặt đã đăng ký)
- 1:N với `Attendance` (bản ghi điểm danh)

#### 3.1.2 Teacher Model (`teacher.py`)
**Bảng:** `teachers`

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | Integer auto | Khóa chính (INT cho tương thích legacy) |
| `user_id` | UUID, unique | FK → User |
| `employee_code` | String(50), unique | Mã nhân viên |
| `phone` | String(20), nullable | Số điện thoại |
| `department` | String(100), nullable | Khoa/Phòng |
| `avatar_url` | String(512), nullable | Ảnh giáo viên |

**Quan hệ:**
- 1:1 với `User`
- 1:N với `Classroom` (lớp giảng dạy)

#### 3.1.3 Student Model (`student.py`)
**Bảng:** `students`

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | Integer auto | Khóa chính (⚠️ INT cho tương thích Flutter) |
| `user_id` | UUID, nullable | FK → User (tài khoản liên kết, nullable) |
| `name` | String(255) | Họ tên sinh viên |
| `pin` | String(10), nullable | Mã PIN (legacy) |
| `job_title` | String(100) | Mã lớp hành chính (⚠️ dùng trường job_title) |
| `academic_class_id` | UUID, nullable | FK → AcademicClass (lớp chủ nhiệm) |
| `avatar_url` | String(512), nullable | URL ảnh sinh viên |
| `has_avatar` | Boolean | Cờ đánh dấu có ảnh |
| `attachment_id` | String(100), nullable | ID tài liệu đính kèm |
| `is_synced` | Boolean | Đã đồng bộ với thiết bị |
| `is_deleted` | Boolean | Soft delete |
| `created_at` | DateTime | Thời gian tạo |
| `updated_at` | DateTime | Thời gian cập nhật |

**Quan hệ:**
- 1:1 với `User` (tài khoản liên kết)
- 1:N với `FaceEmbedding` (nhiều vector khuôn mặt)
- 1:N với `Attendance` (bản ghi điểm danh)
- 1:N với `ClassroomStudent` (đăng ký lớp học)
- N:1 với `AcademicClass` (lớp hành chính)

#### 3.1.4 Classroom Model (`classroom.py`)
**Bảng:** `classes`

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | UUID | Khóa chính |
| `class_name` | String(255) | Tên lớp học |
| `subject` | String(255) | Môn học |
| `teacher_id` | UUID | FK → User (giáo viên sở hữu) |
| `is_deleted` | Boolean | Soft delete |
| `created_at` | DateTime | Thời gian tạo |
| `updated_at` | DateTime | Thời gian cập nhật |

**Quan hệ:**
- N:1 với `User/Teacher`
- 1:N với `AttendanceRecord` (legacy)
- 1:N với `ClassroomStudent` (danh sách sinh viên)
- 1:N với `Schedule` (thời khóa biểu)
- 1:N với `Session` (phiên điểm danh)
- 1:N với `Device` (thiết bị trong phòng)

#### 3.1.5 Attendance Model (`attendance.py`) - Hệ Thống Mới
**Bảng:** `attendance`

Đây là hệ thống điểm danh **mới, dựa trên phiên** (session-based), khác với hệ thống cũ dựa trên lớp học.

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | UUID | Khóa chính |
| `session_id` | UUID | FK → Session (phiên điểm danh) |
| `student_id` | Integer | FK → Student (INT) |
| `user_id` | UUID, nullable | FK → User (tài khoản liên kết) |
| `checkin_time` | DateTime | Thời gian checkin từ thiết bị |
| `sync_time` | DateTime | Thời gian đồng bộ server |
| `status` | Enum | `present` / `late` / `absent` |
| `confidence` | Float, nullable | Độ tin cậy nhận diện khuôn mặt |
| `device_id` | UUID | FK → Device (thiết bị checkin) |
| `is_deleted` | Boolean | Soft delete |
| `created_at` | DateTime | Thời gian tạo |
| `updated_at` | DateTime | Thời gian cập nhật |

**Quan hệ:**
- N:1 với `Session` (phiên điểm danh)
- N:1 với `Student`
- N:1 với `Device`
- N:1 với `User`

#### 3.1.6 FaceEmbedding Model (`face_embedding.py`)
**Bảng:** `face_embeddings`

Lưu trữ vector đặc trưng khuôn mặt 128 chiều dưới dạng JSONB.

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | UUID | Khóa chính |
| `student_id` | Integer | FK → Student |
| `user_id` | UUID, nullable | FK → User |
| `embedding_data` | JSONB | List[float] - vector 128 chiều |
| `is_active` | Boolean | Cờ kích hoạt |
| `device_id` | UUID, nullable | FK → Device (thiết bị đăng ký) |
| `created_at` | DateTime | Thời gian tạo |

**Quan hệ:**
- N:1 với `Student`
- N:1 với `User`
- N:1 với `Device`

#### 3.1.7 Device Model (`device.py`)
**Bảng:** `devices`

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | UUID | Khóa chính |
| `device_code` | String(100), unique | Mã thiết bị |
| `room` | String(100) | Tên phòng học |
| `is_active` | Boolean | Trạng thái hoạt động |
| `device_type` | String(50) | Loại thiết bị |
| `ip_address` | String(45), nullable | Địa chỉ IP |
| `last_active_at` | DateTime, nullable | Thời gian hoạt động cuối |
| `classroom_id` | UUID, nullable | FK → Classroom (phòng học) |
| `created_at` | DateTime | Thời gian tạo |
| `updated_at` | DateTime | Thời gian cập nhật |

**Quan hệ:**
- N:1 với `Classroom`
- 1:N với `Attendance`
- 1:N với `FaceEmbedding`

#### 3.1.8 Session Model (`session.py`)
**Bảng:** `sessions`

Mô hình phiên điểm danh - khung thời gian cho phép điểm danh.

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | UUID | Khóa chính |
| `classroom_id` | UUID | FK → Classroom |
| `schedule_id` | UUID, nullable | FK → Schedule (lịch học gốc) |
| `start_time` | DateTime | Thời gian bắt đầu buổi học |
| `end_time` | DateTime | Thời gian kết thúc buổi học |
| `checkin_start_time` | DateTime | Bắt đầu cho phép điểm danh |
| `checkin_end_time` | DateTime | Kết thúc cho phép điểm danh |
| `status` | Enum | `scheduled` / `active` / `closed` |
| `is_deleted` | Boolean | Soft delete |
| `created_at` | DateTime | Thời gian tạo |
| `updated_at` | DateTime | Thời gian cập nhật |

**Quan hệ:**
- N:1 với `Classroom`
- N:1 với `Schedule`
- 1:N với `Attendance` (bản ghi điểm danh)

#### 3.1.9 TimeSlot Model (`time_slot.py`)
**Bảng:** `time_slots`

Định nghĩa các tiết học (tiết 1, tiết 2, ...).

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | Integer auto | Khóa chính |
| `period_number` | Integer | Số thứ tự tiết (1, 2, 3...) |
| `start_time` | Time | Giờ bắt đầu |
| `end_time` | Time | Giờ kết thúc |

**Quan hệ:**
- 1:N với `Schedule`

#### 3.1.10 Schedule Model (`schedule.py`)
**Bảng:** `schedules`

Lịch học hàng tuần cho mỗi lớp.

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | UUID | Khóa chính |
| `classroom_id` | UUID | FK → Classroom |
| `day_of_week` | Integer | Ngày trong tuần (1=Thứ 2, 7=Chủ Nhật) |
| `time_slot_id` | Integer | FK → TimeSlot |
| `subject_name` | String(255) | Tên môn học |
| `is_deleted` | Boolean | Soft delete |

**Quan hệ:**
- N:1 với `Classroom`
- N:1 với `TimeSlot`
- 1:N với `Session`

#### 3.1.11 ClassroomStudent Model (`classroom_student.py`)
**Bảng:** `classroom_students`

Bảng trung gian cho quan hệ N:N giữa sinh viên và lớp học (đăng ký học).

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | UUID | Khóa chính |
| `classroom_id` | UUID | FK → Classroom |
| `student_id` | Integer | FK → Student (INT) |
| `enrolled_at` | DateTime | Thời gian đăng ký |

**Quan hệ:**
- N:1 với `Classroom`
- N:1 với `Student`

#### 3.1.12 AcademicClass Model (`academic_class.py`)
**Bảng:** `academic_classes`

Lớp hành chính (lớp chủ nhiệm - tương ứng với "lop_chu_quan" trong Flutter).

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | UUID | Khóa chính |
| `code` | String(50), unique | Mã lớp |
| `name` | String(255) | Tên lớp |
| `faculty` | String(100), nullable | Khoa |
| `course_year` | Integer, nullable | Khóa/Năm học |
| `advisor_id` | UUID, nullable | FK → User (giáo viên chủ nhiệm) |
| `is_deleted` | Boolean | Soft delete |

**Quan hệ:**
- N:1 với `User` (giáo viên chủ nhiệm)
- 1:N với `Student` (sinh viên trong lớp)

---

### 3.2 Schemas (Lược Đồ API)

Mỗi module có schema riêng cho request và response, được tổ chức theo pattern:

- **Create schemas**: Validation khi tạo mới
- **Update schemas**: Validation khi cập nhật (thường các trường optional)
- **Out schemas**: Response trả về (thường bao gồm computed fields)
- **List schemas**: Response phân trang/danh sách
- **Legacy schemas**: Tương thích ngược với Flutter (camelCase, envelope `data.*`)

---

### 3.3 Routers (Bộ Định Tuyến)

Router đóng vai trò layer giao diện HTTP, chịu trách nhiệm:
- Định nghĩa endpoint và HTTP method
- Validate request với Pydantic
- Gọi Service tương ứng
- Trả về HTTP response

**Pattern chung:**
```python
@router.post("/path", response_model=SchemaOut)
async def create_item(request: SchemaCreate, db: AsyncSession = Depends(get_db)):
    service = ItemService(db)
    return await service.create(request)
```

---

### 3.4 Services (Nghiệp Vụ)

Chứa toàn bộ business logic:

| Service | Trách nhiệm |
|---------|-------------|
| `AuthService` | Đăng ký, đăng nhập, upload avatar (resize 512px JPEG), logout |
| `UserService` | Truy vấn người dùng |
| `StudentService` | CRUD sinh viên + batch operations cho Flutter |
| `ClassroomService` | CRUD lớp học + kiểm tra quyền sở hữu |
| `AttendanceService` | Checkin real-time + bulk sync offline |
| `FaceService` | Đăng ký vector khuôn mặt, export/import cho Flutter |
| `AntiCheatService` | Chống gian lận điểm danh (validate thiết bị, thời gian, trùng lặp) |

---

### 3.5 Repositories (Truy Vấn DB)

Repository pattern tách biệt logic truy vấn SQLAlchemy khỏi business logic:

| Repository | Trách nhiệm |
|------------|-------------|
| `UserRepository` | CRUD User |
| `StudentRepository` | CRUD Student + bulk create |
| `ClassroomRepository` | CRUD Classroom |
| `AttendanceRepository` | CRUD AttendanceRecord (legacy) |
| `FaceRepository` | CRUD FaceEmbedding + atomic replace |

---

### 3.6 Core (Cấu Hình Cốt Lõi)

#### 3.6.1 Database (`database.py`)
- **AsyncEngine**: `create_async_engine` với `postgresql+asyncpg`
- **Pool**: `pool_size=10`, `max_overflow=20`, `pool_pre_ping=True`
- **Session**: `AsyncSessionLocal` với `expire_on_commit=False`, `autoflush=False`
- **Dependency**: `get_db()` - yields session, auto commit on success, rollback on error
- **Tables**: `create_all_tables()` chạy trong lifespan (chỉ dùng cho dev, production dùng Alembic)

#### 3.6.2 Security (`security.py`)
- **Password**: `CryptContext` hỗ trợ `bcrypt_sha256` (ưu tiên) và `bcrypt` (fallback)
- **JWT**: `jose` library, thuật toán `HS256`, expiry mặc định 24 giờ
- **OAuth2**: `OAuth2PasswordBearer` trỏ đến `/auth/login`
- **Dependency**: `get_current_user_id()` - extract `sub` claim từ bearer token

#### 3.6.3 Rate Limit (`rate_limit.py`)
- **SlowAPI Limiter** với key function `get_remote_address`

#### 3.6.4 Config (`config.py`)
Các biến môi trường quan trọng:

| Biến | Mặc định | Mô tả |
|------|----------|-------|
| `DATABASE_URL` | `postgresql+asyncpg://vedura:vedura_pass@db:5432/vedura_db` | PostgreSQL connection string |
| `SECRET_KEY` | `changeme-...` | Khóa ký JWT (**phải đổi trong production**) |
| `ALGORITHM` | `HS256` | Thuật toán JWT |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `1440` (24h) | Thời gian hết hạn token |
| `UPLOAD_DIR` | `uploads` | Thư mục lưu file upload |
| `DEBUG` | `False` | SQLAlchemy echo mode |
| `CORS_ORIGINS` | `["*"]` | Allowed CORS origins |
| `ENV` | Đọc từ `.env` | Môi trường chạy |

---

## 4. Hệ Thống API Endpoint

### Tổng quan số lượng endpoint theo router

| Router | Số endpoint | Base path |
|--------|------------|-----------|
| `auth_router` | 5 | `/auth` |
| `user_router` | 2 | `/users` |
| `student_router` | 3 | `/students` |
| `classroom_router` | 4 | `/classes` |
| `attendance_router` | 4 | `/attendance` |
| `face_router` | 2 | `/face` |
| `device_router` | 2 | `/devices` |
| `legacy_router` | 8 | `/api` |
| `time_slot_router` | 3 | `/time-slots` |
| `classroom_student_router` | 3 | `/classroom-students` |
| `schedule_router` | 4 | `/schedules` |
| `session_router` | 6 | `/sessions` |
| `attendance_new_router` | 5 | `/attendance/new` |
| `academic_class_router` | 5 | `/academic-classes` |
| **Tổng cộng** | **~56** | |

### Chi tiết endpoint quan trọng

#### Authentication (`/auth`)
| Method | Path | Auth | Mô tả |
|--------|------|------|-------|
| POST | `/auth/register` | ❌ | Đăng ký tài khoản (teacher/student/admin) |
| POST | `/auth/login` | ❌ | Đăng nhập, nhận JWT |
| GET | `/auth/me` | ✅ | Lấy thông tin user hiện tại |
| POST | `/auth/avatar` | ✅ | Upload avatar (resize 512px) |
| POST | `/auth/logout` | ✅ | Logout (stateless) |

#### Session-based Attendance (`/attendance/new`)
| Method | Path | Auth | Mô tả |
|--------|------|------|-------|
| POST | `/attendance/new/` | ✅ | Tạo điểm danh với anti-cheat |
| GET | `/attendance/new/session/{session_id}` | ✅ | Lấy điểm danh theo phiên |
| GET | `/attendance/new/student/{student_id}` | ✅ | Lấy lịch sử điểm danh SV |
| GET | `/attendance/new/{attendance_id}` | ✅ | Lấy 1 bản ghi điểm danh |
| DELETE | `/attendance/new/{attendance_id}` | ✅ | Xóa mềm điểm danh |
| GET | `/attendance/new/summary/session/{session_id}` | ✅ | Thống kê điểm danh |

#### Legacy Flutter (`/api`)
| Method | Path | Auth | Mô tả |
|--------|------|------|-------|
| GET | `/api/employee/get_all_employees` | ✅ | Lấy tất cả nhân viên (Flutter) |
| POST | `/api/employee/create` | ✅ | Tạo 1 nhân viên (Flutter) |
| POST | `/api/employee/create/batch` | ✅ | Batch tạo nhân viên (Flutter) |
| POST | `/api/employee/avatars/upload` | ✅ | Upload avatars (Flutter) |
| GET | `/api/employee/export/json` | ✅ | Export face embeddings (Flutter) |
| PUT | `/api/employee/update/embedding` | ✅ | Import embeddings từ file (Flutter) |
| POST | `/api/attendance/history/sync_bulk_io` | ✅ | Bulk sync điểm danh offline (Flutter) |
| POST | `/api/log/error` | ❌ | Log lỗi từ client |

---

## 5. Hệ Thống Xác Thực & Bảo Mật

### 5.1 JWT Authentication Flow

```
1. User POST /auth/login {email, password}
           ↓
2. AuthService xác thực credentials
           ↓
3. Tạo JWT access_token (HS256, 24h)
           ↓
4. Client lưu token (localStorage/secure storage)
           ↓
5. Mọi request sau đều gửi: Authorization: Bearer <token>
           ↓
6. OAuth2PasswordBearer dependency extract user_id từ token
```

### 5.2 Các Cơ Chế Bảo Mật

| Cơ chế | Mô tả |
|--------|-------|
| **Password Hashing** | bcrypt_sha256 (ưu tiên), bcrypt (fallback) |
| **JWT Tokens** | HS256, 24h expiry, `sub` = user UUID |
| **Soft Delete** | Tất cả model chính có `is_deleted` + `deleted_at` |
| **Anti-Cheat** | Validate thiết bị, thời gian checkin, chống trùng lặp |
| **Rate Limiting** | SlowAPI Limiter (configurable) |
| **CORS** | Configurable origins (default `*`) |
| **Audit Trail** | `created_by`, `updated_by` trên các bảng chính |

### 5.3 CORS Configuration

```python
# Mặc định cho phép tất cả origin
CORS_ORIGINS = ["*"]
# Có thể cấu hình theo môi trường
```

### 5.4 Rate Limiting

```python
# SlowAPI với IP-based rate limiting
limiter = Limiter(key_func=get_remote_address)
```

---

## 6. Hai Hệ Thống Điểm Danh Song Song

### ⚠️ Vấn đề kiến trúc quan trọng

Hệ thống hiện tại duy trì **hai hệ thống điểm danh song song**:

#### Hệ thống Cũ (Legacy)
- **Model**: `AttendanceRecord` (trong `AttendanceRepository`)
- **Bảng**: Có thể là bảng `attendance_records` hoặc `attendance`
- **Cách hoạt động**: Điểm danh trực tiếp theo `class_id`
- **Router**: `attendance_router.py` (`/attendance`)
- **Service**: `attendance_service.py`
- **Repository**: `attendance_repository.py`
- **Schema**: `attendance_schema.py`
- **Dùng bởi**: Legacy endpoints trong `legacy_router.py`

#### Hệ thống MỚI (Session-based)
- **Model**: `Attendance` (bảng `attendance`)
- **Bảng**: `attendance`
- **Cách hoạt động**: Điểm danh thông qua `Session` (phiên điểm danh)
- **Router**: `attendance_new_router.py` (`/attendance/new`)
- **Service**: `AttendanceService` (cùng service, khác method)
- **Anti-Cheat**: `AntiCheatService` kiểm tra thiết bị, thời gian, trùng lặp

### So sánh chi tiết

| Tiêu chí | Hệ thống Cũ | Hệ thống Mới |
|----------|-------------|--------------|
| PK | ? | UUID |
| FK chính | `class_id` | `session_id` |
| FK phụ | `student_id`, `user_id`, `device_id` | `student_id`, `user_id`, `device_id` |
| Thời gian checkin | ? | `checkin_time` + `sync_time` |
| Trạng thái | ? | `present` / `late` / `absent` |
| Độ tin cậy | ? | `confidence` (float) |
| Anti-cheat | ❌ Không | ✅ Có |
| Schema | `attendance_schema.py` | `attendance_new_schema.py` |

### Khuyến nghị

> **Nên thống nhất** thành một hệ thống điểm danh duy nhất (hệ thống mới với session-based approach), và migrate dữ liệu từ hệ thống cũ sang. Việc duy trì hai hệ thống song song gây khó khăn trong bảo trì và có thể dẫn đến inconsistency dữ liệu.

---

## 7. Tương Thích Flutter

### 7.1 Legacy Endpoints (`legacy_router.py`)

Cung cấp các endpoint tương thích với ứng dụng Flutter hiện có:

#### Endpoint nhân viên (Employee)
- `GET /api/employee/get_all_employees` → Trả về danh sách employee với envelope `data.employees`
- `POST /api/employee/create` → Tạo 1 employee
- `POST /api/employee/create/batch` → Tạo nhiều employee cùng lúc
- `POST /api/employee/avatars/upload` → Upload batch avatar images

#### Endpoint khuôn mặt
- `GET /api/employee/export/json` → Export tất cả face embeddings (Flutter pull)
- `PUT /api/employee/update/embedding` → Import embeddings từ JSON file (Flutter push)

#### Endpoint điểm danh
- `POST /api/attendance/history/sync_bulk_io` → Bulk sync điểm danh offline

### 7.2 Đặc điểm tương thích

| Vấn đề | Giải pháp |
|--------|-----------|
| Flutter dùng `classId` (camelCase) | Schemas dùng `ClassId` hoặc đã config `fieldRename` |
| Student PK là INTEGER | Model `Student` dùng `Integer` primary key |
| Face embeddings 128-d vector | Lưu trong JSONB dưới dạng `List[float]` |
| Bulk operations | `batch_create_employees()`, `bulk_sync()` |
| Export/Import face data | `FaceService.export_all()`, `FaceService.import_from_file()` |

### 7.3 Flutter Data Flow

```
┌─────────────────┐     REST API      ┌─────────────────┐
│  Flutter App    │ ←───────────────→  │   FastAPI       │
│  (Face SDK)     │                    │   Backend       │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         │  1. Employee CRUD                   │
         │  2. Face Embedding Register         │
         │  3. Export/Import for offline sync  │
         │  4. Attendance Sync                 │
         │                                      │
         ↓                                      ↓
┌─────────────────┐                    ┌─────────────────┐
│  Device Local   │ ←─────────────────→│   PostgreSQL    │
│  (SQLite/Cache) │   Sync offline     │                 │
└─────────────────┘                    └─────────────────┘
```

---

## 8. Các Vấn Đề Tiềm Ẩn

### 8.1 Vấn đề nghiêm trọng

#### ❌ Inconsistency giữa Repository và Model
- `AttendanceRepository` import `AttendanceRecord` từ `app.models.attendance`
- Nhưng `app/models/attendance.py` chỉ định nghĩa class `Attendance`
- `app/models/__init__.py` có import cả `AttendanceRecord` và `Attendance`
- **Ảnh hưởng**: Code sẽ crash khi `AttendanceRepository` được import

#### ❌ Student model dùng `job_title` cho `academic_class_id`
- Trường `job_title` (String) trong `Student` model được dùng để lưu mã lớp hành chính
- Trong khi `academic_class_id` (UUID FK) là quan hệ chính thức
- **Ảnh hưởng**: Dữ liệu bị phân mảnh, khó query và maintain

#### ❌ Hai hệ thống điểm danh song song
- Hệ thống cũ và mới dùng các bảng và logic khác nhau
- Không có cơ chế sync giữa hai hệ thống
- **Ảnh hưởng**: Báo cáo không nhất quán, khó debug

### 8.2 Vấn đề bảo mật

#### ⚠️ CORS cho phép tất cả origins
```python
CORS_ORIGINS = ["*"]  # Mặc định
```
**Rủi ro**: Cho phép request từ bất kỳ domain nào.

#### ⚠️ SECRET_KEY mặc định
```python
SECRET_KEY = "changeme-..."  # Giá trị mặc định trong config
```
**Rủi ro**: Nếu không đổi trong `.env`, JWT có thể bị giả mạo.

#### ⚠️ Rate limiting mặc định
- Không có rate limit cụ thể được cấu hình mặc định
- Có thể bị brute-force attack trên `/auth/login`

### 8.3 Vấn đề hiệu năng

#### ⚠️ Không có database indexes rõ ràng
- Chưa thấy index được định nghĩa trên các trường thường query (`student_id`, `class_id`, `session_id`, `user_id`)

#### ⚠️ Soft delete không filter mặc định
- Các query trong repository không tự động filter `is_deleted=True`
- Cần kiểm tra từng repository method

### 8.4 Vấn đề kiến trúc

#### ⚠️ `get_db()` dùng autocommit=False
```python
async with AsyncSessionLocal() as session:
    yield session
    await session.commit()  # Nếu không exception
```
- Mỗi request thành công đều commit
- Nhưng nếu có exception trong route handler sau khi yield, rollback không được gọi rõ ràng

#### ⚠️ Không có global exception handler cho database errors
- Chỉ có handler cho `RequestValidationError`, `HTTPException`, và generic `Exception`
- Database errors (constraint violation, connection timeout) sẽ trả về 500 không có message rõ ràng

---

## 9. Đề Xuất Cải Thiện

### 9.1 Ngắn hạn (Quick Wins)

| # | Hành động | Lý do | Mức độ ưu tiên |
|---|-----------|-------|----------------|
| 1 | **Fix import inconsistency** `AttendanceRecord` vs `Attendance` | Crash khi import repository | 🔴 Cao |
| 2 | **Thêm index** trên `student_id`, `class_id`, `session_id`, `user_id` | Query chậm khi bảng lớn | 🔴 Cao |
| 3 | **Cấu hình CORS** theo môi trường | Bảo mật | 🟡 Trung |
| 4 | **Đổi SECRET_KEY** trong production | Bảo mật JWT | 🔴 Cao |
| 5 | **Thêm rate limit** cho `/auth/login` | Chống brute-force | 🟡 Trung |

### 9.2 Trung hạn

| # | Hành động | Lý do | Mức độ ưu tiên |
|---|-----------|-------|----------------|
| 6 | **Thống nhất hệ thống điểm danh** - migrate legacy sang session-based | Duy trì 2 hệ thống tốn công | 🟡 Trung |
| 7 | **Thêm `is_deleted` filter** trong tất cả repository methods | Đảm bảo soft delete hoạt động | 🟡 Trung |
| 8 | **Migrate `job_title` → `academic_class_id`** trong Student | Dữ liệu nhất quán | 🟡 Trung |
| 9 | **Thêm database indexes** cho các trường thường query | Hiệu năng | 🟡 Trung |
| 10 | **Thêm global exception handler** cho database errors | Debug dễ hơn | 🟢 Thấp |

### 9.3 Dài hạn

| # | Hành động | Lý do | Mức độ ưu tiên |
|---|-----------|-------|----------------|
| 11 | **Xây dựng hệ thống báo cáo** thống nhất | Analytics cho admin | 🟢 Thấp |
| 12 | **Thêm WebSocket** cho real-time attendance updates | Trải nghiệm người dùng | 🟢 Thấp |
| 13 | **API versioning** (`/v1/`, `/v2/`) | Backward compatibility | 🟢 Thấp |
| 14 | **Thêm unit tests** cho services và repositories | Đảm bảo chất lượng code | 🟢 Thấp |
| 15 | **CICD pipeline** (Docker + CI/CD) | Deploy tự động | 🟢 Thấp |

### 9.4 Migration Plan cho Attendance System

```
Giai đoạn 1: Phân tích & thiết kế
  ├── Đánh giá schema hiện tại của cả hai hệ thống
  ├── Thiết kế schema thống nhất (dựa trên Attendance model mới)
  └── Lên kế hoạch migration dữ liệu

Giai đoạn 2: Implement hệ thống mới
  ├── Cập nhật Attendance model với đầy đủ fields
  ├── Cập nhật AttendanceService
  ├── Cập nhật AttendanceRepository (fix import)
  ├── Viết migration script (Alembic)
  └── Viết API endpoints mới

Giai đoạn 3: Migrate dữ liệu
  ├── Viết script migration: legacy → new system
  ├── Validate dữ liệu sau migration
  ├── Backup trước khi migrate production
  └── Execute migration

Giai đoạn 4: Deprecate hệ thống cũ
  ├── Cập nhật Flutter app để dùng endpoints mới
  ├── Giữ legacy endpoints trong 1 version để rollback
  └── Xóa legacy code sau khi stable
```

---

## Tổng Kết

| Khía cạnh | Đánh giá |
|-----------|----------|
| **Kiến trúc** | ✅ Tốt - Clean 3-layer, async throughout |
| **Bảo mật** | ⚠️ Cần cải thiện - CORS *, SECRET_KEY mặc định |
| **Code quality** | ⚠️ Có vấn đề - import inconsistency, duplicate systems |
| **Tương thích Flutter** | ✅ Tốt - Legacy endpoints đầy đủ |
| **Mở rộng** | ⚠️ Cần cải thiện - Index, rate limit, exception handling |
| **Anti-cheat** | ✅ Đã implement - Device, time window, duplicate detection |

**Điểm mạnh:**
- Kiến trúc clean, dễ mở rộng
- Hỗ trợ async PostgreSQL tốt
- Anti-cheat service cho attendance
- Legacy endpoints cho Flutter

**Cần cải thiện ngay:**
1. Fix import inconsistency (`AttendanceRecord` vs `Attendance`)
2. Thêm database indexes
3. Cấu hình bảo mật production
4. Thống nhất hệ thống điểm danh
