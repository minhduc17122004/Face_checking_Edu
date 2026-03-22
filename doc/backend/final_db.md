# Cơ Sở Dữ Liệu — Face Time Keeping System

> **Ngày cập nhật:** 2026-03-21  
> **Database:** PostgreSQL + SQLAlchemy 2.x (async)  
> **Trạng thái:** Production-ready sau Migration 0014

---

## Mục Lục

1. [Tổng Quan Schema](#1-tổng-quan-schema)
2. [ERD - Sơ Đồ Quan Hệ Thực Thể](#2-erd---sơ-đồ-quan-hệ-thực-thể)
3. [Chi Tiết Từng Bảng](#3-chi-tiết-từng-bảng)
4. [Indexes & Constraints](#4-indexes--constraints)
5. [Migrations Timeline](#5-migrations-timeline)
6. [Design Decisions](#6-design-decisions)
7. [Tương Thích Flutter](#7-tương-thích-flutter)

---

## 1. Tổng Quan Schema

### Tổng số bảng: 13

| # | Bảng | Mục đích | PK | FK |
|---|------|----------|----|----|
| 1 | `users` | Bảng xác thực trung tâm | UUID | — |
| 2 | `teachers` | Hồ sơ giáo viên | INT | `users.id` |
| 3 | `students` | Hồ sơ sinh viên | INT | `users.id`, `student_groups.id` |
| 4 | `student_groups` | Lớp hành chính (lớp chủ quản) | UUID | `users.id` (advisor) |
| 5 | `courses` | Lớp học phần | UUID | `users.id` (instructor) |
| 6 | `course_enrollments` | Đăng ký sinh viên — lớp học phần | UUID | `courses.id`, `students.id` |
| 7 | `time_slots` | Định nghĩa tiết học (toàn cục) | INT | — |
| 8 | `schedules` | Lịch học hàng tuần | UUID | `courses.id`, `time_slots.id` |
| 9 | `sessions` | Phiên điểm danh cụ thể | UUID | `courses.id`, `schedules.id` |
| 10 | `attendance` | Bản ghi điểm danh | UUID | `sessions.id`, `students.id`, `devices.id` |
| 11 | `face_embeddings` | Vector khuôn mặt 128 chiều | UUID | `students.id`, `devices.id` |
| 12 | `devices` | Thiết bị điểm danh | UUID | `courses.id` |
| 13 | `refresh_tokens` | Refresh token có thể thu hồi | UUID | `users.id` |

---

## 2. ERD - Sơ Đồ Quan Hệ Thực Thể

```
┌──────────────┐         ┌──────────────┐
│    users     │────────▶│   teachers    │
│  (UUID PK)   │   1:1   │  (INT PK)    │
└──────┬───────┘         └──────────────┘
       │ 1:1
       ▼
┌──────────────┐         ┌──────────────────┐
│   students   │────────▶│ student_groups    │
│  (INT PK)    │  N:1    │    (UUID PK)     │
└──────┬───────┘         └──────────────────┘
       │
       │ N:M (qua course_enrollments)
       ▼
┌──────────────────┐         ┌──────────────┐
│ course_enrollments│◀────────│   courses    │
│   (UUID PK)      │   N:1   │  (UUID PK)   │
└────────┬─────────┘         └──────┬───────┘
         │                          │
         │ N:M (qua schedules)      │ 1:N
         ▼                          ▼
┌──────────────────┐         ┌──────────────┐
│    schedules     │────────▶│  time_slots  │
│   (UUID PK)     │  N:1    │  (INT PK)    │
└────────┬─────────┘         └──────────────┘
         │
         │ 1:N (optional)
         ▼
┌──────────────────┐         ┌──────────────┐
│    sessions      │────────▶│   courses    │
│   (UUID PK)     │  N:1    │              │
└────────┬─────────┘         └──────┬───────┘
         │
         │ 1:N
         ▼
┌──────────────────┐
│   attendance     │
│   (UUID PK)      │
└────────┬─────────┘
         │ N:1
         ▼
┌──────────────────┐
│    students      │
│  (INT FK)        │
└──────────────────┘
         │
         │ 1:N
         ▼
┌──────────────────┐         ┌──────────────┐
│ face_embeddings  │────────▶│   devices    │
│   (UUID PK)     │  N:1    │  (UUID PK)   │
└──────────────────┘         └──────────────┘

┌──────────────────┐
│ refresh_tokens   │────────▶ users (UUID FK)
│   (UUID PK)     │
└──────────────────┘
```

### Luồng Điểm Danh

```
users ───(1:1)─── students ───(N:M)─── courses
                              │
                              └───(qua course_enrollments)
                                      │
                                      ▼
sessions ────(1:N)─── attendance
(phiên cụ thể)       (bản ghi điểm danh)
```

---

## 3. Chi Tiết Từng Bảng

### 3.1 `users` — Bảng Xác Thực Trung Tâm

**Single Source of Truth** cho identity và avatar.

```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(255) NOT NULL,
    role            VARCHAR(20) NOT NULL DEFAULT 'student'
                     CHECK (role IN ('admin', 'teacher', 'student')),
    avatar_url      VARCHAR(500),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,  -- Soft delete (chỉ deleted_at, KHÔNG có is_deleted)
    CONSTRAINT ck_users_role CHECK (role IN ('admin', 'teacher', 'student'))
);

CREATE INDEX ix_users_email ON users(email);
CREATE INDEX ix_users_deleted_at ON users(deleted_at);
```

| Trường | Kiểu | Mô tả |
|--------|------|-------|
| `id` | UUID | Khóa chính |
| `email` | String(255), unique | Email đăng nhập, có index |
| `password_hash` | String(255) | bcrypt hash |
| `full_name` | String(255) | Họ tên đầy đủ |
| `role` | Enum | `admin`, `teacher`, `student` |
| `avatar_url` | String(500), nullable | **Single source of truth** — avatar chỉ lưu ở đây |
| `deleted_at` | DateTime, nullable | Soft delete (chỉ dùng trường này) |

**Computed Properties (trong User model):**
- `student_code` → lấy từ `student_profile.student_code`
- `class_name` → lấy từ `student_profile.student_group.name` (teacher: `teacher_profile.department`)
- `display_name` → fallback từ `full_name` sang `email.split("@")[0]`

**Quan hệ:**
- 1:1 với `Teacher` (`teacher_profile`)
- 1:1 với `Student` (`student_profile`)
- 1:N với `Course` (`courses` — giáo viên giảng dạy)
- 1:N với `StudentGroup` (`advised_groups` — cố vấn học tập)
- 1:N với `RefreshToken` (`refresh_tokens`)

---

### 3.2 `teachers` — Hồ Sơ Giáo Viên

```sql
CREATE TABLE teachers (
    id            INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id       UUID NOT NULL UNIQUE
                   REFERENCES users(id) ON DELETE CASCADE,
    teacher_id    VARCHAR(50) UNIQUE,    -- Mã cán bộ (đã đổi từ employee_code)
    phone         VARCHAR(20),
    department    VARCHAR(255),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMPTZ,
    -- KHÔNG có avatar_url (dùng users.avatar_url)
);

CREATE INDEX ix_teachers_user_id ON teachers(user_id);
CREATE INDEX ix_teachers_deleted_at ON teachers(deleted_at);
```

**Đặc điểm:**
- Strict 1:1 với `users` (`user_id UNIQUE NOT NULL`)
- Avatar lấy từ `users.avatar_url` (single source of truth)
- `teacher_id` (trước đây là `employee_code`) — mã cán bộ duy nhất

---

### 3.3 `students` — Hồ Sơ Sinh Viên

```sql
CREATE TABLE students (
    id              INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id         UUID NOT NULL UNIQUE
                     REFERENCES users(id) ON DELETE CASCADE,
    student_code    VARCHAR(50) UNIQUE,  -- MSSV
    pin             VARCHAR(10),          -- PIN offline
    student_group_id UUID
                     REFERENCES student_groups(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    created_by      UUID,
    updated_by      UUID,
    -- KHÔNG có: avatar_url, has_avatar, attachment_id, is_synced, name (đã xóa)
);

CREATE INDEX ix_students_user_id ON students(user_id);
CREATE INDEX ix_students_student_code ON students(student_code);
CREATE INDEX ix_students_student_group_id ON students(student_group_id);
CREATE INDEX ix_students_deleted_at ON students(deleted_at);
```

**Đặc điểm:**
- **INT PK** — tương thích Flutter (Flutter parse `id` là `int`)
- Strict 1:1 với `users` (`user_id UNIQUE NOT NULL`)
- `student_group_id` → lớp hành chính/chủ quản (N:1)
- Đã xóa các trường thừa: `avatar_url`, `has_avatar`, `attachment_id`, `is_synced`, `name`
- Computed properties: `name`, `avatar_url`, `has_avatar` → lấy từ `user`

---

### 3.4 `student_groups` — Lớp Hành Chính (Lớp Chủ Quản)

```sql
CREATE TABLE student_groups (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code        VARCHAR(50) NOT NULL UNIQUE,  -- ví dụ: "48K22"
    name        VARCHAR(255),                  -- ví dụ: "Khoa CNTT - K22"
    faculty     VARCHAR(255),
    course_year VARCHAR(10),                   -- ví dụ: "K22"
    advisor_id  UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ,
    created_by  UUID,
    updated_by  UUID,
    -- Đã đổi tên: academic_classes → student_groups
);

CREATE UNIQUE INDEX ix_student_groups_code ON student_groups(code);
CREATE INDEX ix_student_groups_advisor_id ON student_groups(advisor_id);
```

**Ví dụ dữ liệu:**
- Code: `48K22` — (48 = mã khoa, K22 = khóa 22)
- Faculty: `Khoa Công Nghệ Thông Tin`
- Course Year: `K22`

---

### 3.5 `courses` — Lớp Học Phần

```sql
CREATE TABLE courses (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_name   VARCHAR(255) NOT NULL,     -- đã đổi từ class_name
    subject       VARCHAR(255),
    course_code   VARCHAR(50),               -- mã lớp học phần
    instructor_id UUID REFERENCES users(id) ON DELETE SET NULL,  -- đã đổi từ teacher_id
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMPTZ,
    created_by    UUID,
    updated_by    UUID,
    -- Đã đổi tên: classes → courses
);

CREATE INDEX ix_courses_instructor_id ON courses(instructor_id);
CREATE INDEX ix_courses_deleted_at ON courses(deleted_at);
```

**Đặc điểm:**
- Giáo viên tạo và sở hữu lớp học phần
- `course_code` — mã đăng ký học phần (mới, migration 0014)
- Quan hệ với: schedules, sessions, devices, course_enrollments

---

### 3.6 `course_enrollments` — Đăng Ký Sinh Viên

```sql
CREATE TABLE course_enrollments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id   UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    student_id  INT  NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Đã đổi tên: classroom_students → course_enrollments
    CONSTRAINT uq_enrollment_course_student UNIQUE (course_id, student_id)
);

CREATE INDEX ix_enrollment_course_id ON course_enrollments(course_id);
CREATE INDEX ix_enrollment_student_id ON course_enrollments(student_id);
CREATE INDEX ix_enrollment_course_student ON course_enrollments(course_id, student_id);
```

**Đặc điểm:**
- Quan hệ N:N giữa sinh viên và lớp học phần
- UNIQUE constraint trên `(course_id, student_id)` — ngăn đăng ký trùng lặp

---

### 3.7 `time_slots` — Định Nghĩa Tiết Học

```sql
CREATE TABLE time_slots (
    id             INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    period_number  INT NOT NULL UNIQUE,  -- 1, 2, 3, ...
    start_time     TIME NOT NULL,
    end_time       TIME NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_time_slot_order CHECK (start_time < end_time)
);
```

**Dữ liệu mặc định (8 tiết):**

| Tiết | Thời gian |
|------|-----------|
| 1 | 07:30 - 08:15 |
| 2 | 08:20 - 09:05 |
| 3 | 09:10 - 09:55 |
| 4 | 10:00 - 10:45 |
| 5 | 10:50 - 11:35 |
| 6 | 13:00 - 13:45 |
| 7 | 13:50 - 14:35 |
| 8 | 14:40 - 15:25 |

---

### 3.8 `schedules` — Lịch Học Hàng Tuần

```sql
CREATE TABLE schedules (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id    UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    day_of_week  INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    time_slot_id INT NOT NULL REFERENCES time_slots(id),
    room         VARCHAR(100),           -- đã đổi từ subject_name
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at   TIMESTAMPTZ,
    created_by   UUID,
    updated_by   UUID,
    -- đã đổi: classroom_id → course_id, subject_name → room
    CONSTRAINT uq_schedule_course_day_slot UNIQUE (course_id, day_of_week, time_slot_id)
);

CREATE INDEX ix_schedules_course_id ON schedules(course_id);
CREATE INDEX ix_schedules_deleted_at ON schedules(deleted_at);
```

**Đặc điểm:**
- `day_of_week`: 1 = Thứ 2, 7 = Chủ Nhật
- UNIQUE constraint ngăn lịch trùng lặp

---

### 3.9 `sessions` — Phiên Điểm Danh

```sql
CREATE TABLE sessions (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id             UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    schedule_id           UUID REFERENCES schedules(id) ON DELETE SET NULL,
    session_date          DATE NOT NULL,
    start_time            TIMESTAMPTZ NOT NULL,
    end_time              TIMESTAMPTZ,
    checkin_window_start  TIMESTAMPTZ,   -- đã đổi từ checkin_start_time
    checkin_window_end    TIMESTAMPTZ,   -- đã đổi từ checkin_end_time
    status                VARCHAR(20) NOT NULL DEFAULT 'scheduled'
                           CHECK (status IN ('scheduled', 'active', 'closed')),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at            TIMESTAMPTZ,
    -- đã đổi: classroom_id → course_id
);

CREATE INDEX ix_sessions_course_id ON sessions(course_id);
CREATE INDEX ix_sessions_course_start ON sessions(course_id, start_time);
CREATE INDEX ix_sessions_status ON sessions(status);
CREATE INDEX ix_sessions_deleted_at ON sessions(deleted_at);
```

**Trạng thái phiên:**
- `scheduled`: Đã lên kế hoạch
- `active`: Đang điểm danh (tự động chuyển khi đến `start_time`)
- `closed`: Đã đóng (tự động chuyển khi đến `end_time`)

**Auto-transition:**
- `scheduled → active`: Khi `start_time` đến (triggered on app startup + on check-in)
- `active → closed`: Khi `end_time` đến

---

### 3.10 `attendance` — Bản Ghi Điểm Danh

```sql
CREATE TABLE attendance (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id    UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    student_id    INT  NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    checkin_time  TIMESTAMPTZ NOT NULL,  -- Giờ thiết bị gửi (offline-first)
    sync_time     TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- Giờ server nhận
    status        VARCHAR(20) NOT NULL DEFAULT 'present'
                   CHECK (status IN ('present', 'late', 'absent')),
    confidence    FLOAT,                   -- Độ tin cậy nhận diện khuôn mặt
    device_id     UUID REFERENCES devices(id) ON DELETE SET NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMPTZ,
    -- CHỈ dùng student_id, KHÔNG dùng user_id (unified identity)
    CONSTRAINT uq_attendance_session_student UNIQUE (session_id, student_id)
);

CREATE INDEX ix_attendance_session_id ON attendance(session_id);
CREATE INDEX ix_attendance_student_id ON attendance(student_id);
CREATE INDEX ix_attendance_session_student ON attendance(session_id, student_id);
CREATE INDEX ix_attendance_checkin_time ON attendance(checkin_time);
CREATE INDEX ix_attendance_status ON attendance(status);
CREATE INDEX ix_attendance_created_at ON attendance(created_at);
```

**Đặc điểm:**
- **Dual timestamps**: `checkin_time` (thiết bị) + `sync_time` (server) — hỗ trợ offline
- **Unified identity**: Chỉ dùng `student_id`, không dùng `user_id` (sau migration 0011)
- UNIQUE constraint `(session_id, student_id)` — ngăn điểm danh trùng lặp

---

### 3.11 `face_embeddings` — Vector Khuôn Mặt

```sql
CREATE TABLE face_embeddings (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id    INT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    embedding     JSON NOT NULL,          -- list[128 floats] — vector 128 chiều
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    quality_score FLOAT,                  -- Chất lượng khuôn mặt (0.0-1.0)
    device_id     UUID REFERENCES devices(id) ON DELETE SET NULL,
    captured_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMPTZ,
    -- CHỈ dùng student_id, KHÔNG dùng user_id (unified identity)
    -- đã đổi: embedding_data → embedding
);

CREATE INDEX ix_face_embeddings_student_id ON face_embeddings(student_id);
CREATE INDEX ix_face_embeddings_active_student ON face_embeddings(student_id)
    WHERE is_active = true;  -- Partial index
```

**Đặc điểm:**
- **128 chiều**: JSON array 128 số float (FaceNet embedding)
- **Max-5 FIFO**: Mỗi sinh viên tối đa 5 embeddings; vượt quá → xóa cũ nhất
- **Partial index** trên `is_active = true` — tối ưu cho tìm kiếm

---

### 3.12 `devices` — Thiết Bị Điểm Danh

```sql
CREATE TABLE devices (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_code   VARCHAR(50) NOT NULL UNIQUE,
    device_name   VARCHAR(100),
    room          VARCHAR(100),
    device_type   VARCHAR(50) NOT NULL DEFAULT 'tablet',
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    ip_address    VARCHAR(45),
    mac_address   VARCHAR(17),
    course_id     UUID REFERENCES courses(id) ON DELETE SET NULL,  -- đã đổi: classroom_id → course_id
    last_active_at TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMPTZ,
    created_by    UUID,
    updated_by    UUID,
);

CREATE UNIQUE INDEX ix_devices_code ON devices(device_code);
CREATE INDEX ix_devices_course_id ON devices(course_id);
CREATE INDEX ix_devices_is_active ON devices(is_active);
```

**Đặc điểm:**
- Hardware registry — không chứa business logic
- Optional binding tới `courses.id` (device có thể dùng chung hoặc gán riêng)
- `device_type`: `tablet`, `kiosk`, `webcam`, ...

---

### 3.13 `refresh_tokens` — Refresh Token Có Thu Hồi

```sql
CREATE TABLE refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_jti   VARCHAR(64) NOT NULL UNIQUE,  -- Hashed JWT jti claim
    device_id   VARCHAR(255),
    device_info JSONB,                         -- metadata: browser, OS, ...
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX ix_refresh_tokens_token_jti ON refresh_tokens(token_jti);
```

**Đặc điểm:**
- **Có thể thu hồi**: `revoked` flag + `expires_at`
- **Hashed JTI**: `token_jti` là hash, không lưu token thật
- Hỗ trợ multi-device: `device_id` + `device_info`

---

## 4. Indexes & Constraints

### 4.1 Primary Keys

| Bảng | PK Type | Lý do |
|------|---------|--------|
| `users` | UUID | Global identity, distributed |
| `teachers` | INT auto | Legacy compatibility |
| `students` | INT auto | **Flutter compatibility** (parse id as int) |
| `student_groups` | UUID | Domain entity |
| `courses` | UUID | Domain entity |
| `course_enrollments` | UUID | Junction table |
| `time_slots` | INT auto | Reference data |
| `schedules` | UUID | Domain entity |
| `sessions` | UUID | Domain entity |
| `attendance` | UUID | Domain entity |
| `face_embeddings` | UUID | Domain entity |
| `devices` | UUID | Domain entity |
| `refresh_tokens` | UUID | Auth entity |

### 4.2 Unique Constraints

| Constraint | Bảng | Cột |
|------------|------|-----|
| `uq_users_email` | `users` | `email` |
| `uq_teachers_user_id` | `teachers` | `user_id` |
| `uq_teachers_teacher_id` | `teachers` | `teacher_id` |
| `uq_students_user_id` | `students` | `user_id` |
| `uq_students_student_code` | `students` | `student_code` |
| `uq_student_groups_code` | `student_groups` | `code` |
| `uq_devices_code` | `devices` | `device_code` |
| `uq_attendance_session_student` | `attendance` | `(session_id, student_id)` |
| `uq_enrollment_course_student` | `course_enrollments` | `(course_id, student_id)` |
| `uq_schedule_course_day_slot` | `schedules` | `(course_id, day_of_week, time_slot_id)` |
| `uq_refresh_tokens_jti` | `refresh_tokens` | `token_jti` |

### 4.3 Indexes Chi Tiết

| Index | Bảng | Cột | Loại |
|-------|------|-----|------|
| `ix_users_email` | `users` | `email` | B-tree |
| `ix_users_deleted_at` | `users` | `deleted_at` | B-tree |
| `ix_teachers_user_id` | `teachers` | `user_id` | B-tree |
| `ix_teachers_deleted_at` | `teachers` | `deleted_at` | B-tree |
| `ix_students_user_id` | `students` | `user_id` | B-tree |
| `ix_students_student_code` | `students` | `student_code` | B-tree |
| `ix_students_student_group_id` | `students` | `student_group_id` | B-tree |
| `ix_students_deleted_at` | `students` | `deleted_at` | B-tree |
| `ix_student_groups_code` | `student_groups` | `code` | B-tree |
| `ix_student_groups_advisor_id` | `student_groups` | `advisor_id` | B-tree |
| `ix_courses_instructor_id` | `courses` | `instructor_id` | B-tree |
| `ix_courses_deleted_at` | `courses` | `deleted_at` | B-tree |
| `ix_enrollment_course_id` | `course_enrollments` | `course_id` | B-tree |
| `ix_enrollment_student_id` | `course_enrollments` | `student_id` | B-tree |
| `ix_enrollment_course_student` | `course_enrollments` | `(course_id, student_id)` | Composite |
| `ix_schedules_course_id` | `schedules` | `course_id` | B-tree |
| `ix_schedules_deleted_at` | `schedules` | `deleted_at` | B-tree |
| `ix_sessions_course_id` | `sessions` | `course_id` | B-tree |
| `ix_sessions_course_start` | `sessions` | `(course_id, start_time)` | Composite |
| `ix_sessions_status` | `sessions` | `status` | B-tree |
| `ix_sessions_deleted_at` | `sessions` | `deleted_at` | B-tree |
| `ix_attendance_session_id` | `attendance` | `session_id` | B-tree |
| `ix_attendance_student_id` | `attendance` | `student_id` | B-tree |
| `ix_attendance_session_student` | `attendance` | `(session_id, student_id)` | Composite |
| `ix_attendance_checkin_time` | `attendance` | `checkin_time` | B-tree |
| `ix_attendance_status` | `attendance` | `status` | B-tree |
| `ix_attendance_created_at` | `attendance` | `created_at` | B-tree |
| `ix_face_embeddings_student_id` | `face_embeddings` | `student_id` | B-tree |
| `ix_face_embeddings_active_student` | `face_embeddings` | `student_id` | Partial (is_active=true) |
| `ix_devices_code` | `devices` | `device_code` | B-tree |
| `ix_devices_course_id` | `devices` | `course_id` | B-tree |
| `ix_devices_is_active` | `devices` | `is_active` | B-tree |
| `ix_refresh_tokens_user_id` | `refresh_tokens` | `user_id` | B-tree |
| `ix_refresh_tokens_token_jti` | `refresh_tokens` | `token_jti` | B-tree |

---

## 5. Migrations Timeline

| # | File | Ngày | Thay đổi chính |
|---|------|------|----------------|
| 0001 | `0001_initial_schema.py` | — | users, teachers, students, classes, face_embeddings, attendance_records |
| 0002 | `0002_add_avatar_url_to_users.py` | — | Thêm avatar_url → users |
| 0003 | `0003_expand_schema.py` | — | time_slots, classroom_students, schedules, sessions, attendance, devices |
| 0004 | `0004_migrate_attendance_data.py` | — | Di chuyển dữ liệu điểm danh |
| 0005 | `0005_create_academic_classes.py` | — | Tạo bảng academic_classes |
| 0006 | `0006_add_academic_class_to_students.py` | — | Thêm academic_class_id → students |
| 0007 | `0007_fix_session_timestamps.py` | — | Sửa timestamp cho sessions |
| 0008 | `0008_add_attendance_fields.py` | — | Thêm trường mở rộng cho attendance |
| 0009 | `0009_enhance_devices.py` | — | Thêm anti-cheat fields, room, location |
| 0010 | `0010_add_soft_delete_audit.py` | — | Thêm is_deleted, deleted_at, created_by, updated_by |
| 0011 | `0011_unify_attendance_identity.py` | 19/03 | Xóa user_id khỏi attendance & face_embeddings; thêm indexes |
| 0012 | `0012_add_refresh_tokens_and_device_auth.py` | 19/03 | refresh_tokens table; device authentication |
| 0013 | `0013_data_integrity.py` | 19/03 | UNIQUE constraint (session_id, student_id); partial index |
| 5e31f59 | `20260320_1718_5e31f594dece_add_student_code_to_students.py` | 20/03 | Thêm student_code → students |
| abcdef12 | `20260320_2000_123456789abc_rename_employee_code.py` | 20/03 | Đổi employee_code → teacher_id trong teachers |
| 0014 | `0014_refactor_schema.py` | 20/03 | **TÁI CẤU TRÚC LỚN**: đổi tên bảng/cột, xóa trường thừa, enforce 1:1 |

---

## 6. Design Decisions

### 6.1 Tại sao `student.id` là INT?

Flutter `Student.fromJson()` parse `id` là `int`. Nếu dùng UUID, Flutter app sẽ crash hoặc cần refactor lớp Student model. Giải pháp: giữ INT PK cho `students`, dùng UUID cho tất cả bảng khác.

### 6.2 Tại sao chỉ `deleted_at`, không có `is_deleted`?

Sau migration 0014, tất cả bảng dùng **chỉ `deleted_at`** cho soft delete. `is_deleted` là dư thừa vì `deleted_at IS NULL` = chưa xóa, `deleted_at IS NOT NULL` = đã xóa. Việc này giảm redundancy và đơn giản hóa logic.

### 6.3 Tại sao unified identity (chỉ `student_id`)?

Trước đây attendance và face_embeddings dùng cả `user_id` và `student_id`. Điều này gây inconsistency. Migration 0011 thống nhất: chỉ dùng `student_id` (INT), không dùng `user_id` (UUID).

### 6.4 Tại sao JSON cho face embeddings?

Lưu vector 128 chiều dưới dạng JSON array. **pgvector** là lựa chọn tốt hơn cho production:
```sql
ALTER TABLE face_embeddings ALTER COLUMN embedding TYPE vector(128);
CREATE INDEX ON face_embeddings USING ivfflat (embedding vector_cosine_ops);
```
Hiện tại dùng JSON để tương thích với cơ sở hạ tầng hiện có.

### 6.5 Tại sao Max-5 FIFO cho face embeddings?

- Mỗi sinh viên có thể đăng ký nhiều góc mặt/khác nhau (FIFO)
- Giới hạn 5 bản ghi tránh storage bloat
- Khi vượt quá 5 → xóa bản ghi cũ nhất (`created_at ASC`)

### 6.6 Tại sao dual timestamps cho attendance?

- `checkin_time`: Thời gian thiết bị gửi (hỗ trợ offline)
- `sync_time`: Thời gian server nhận (authoritative timestamp)

---

## 7. Tương Thích Flutter

### 7.1 Những gì Flutter cần biết

| Vấn đề | Giải pháp |
|---------|-----------|
| Student PK là INT | Model `Student` dùng `Integer` primary key |
| Face embeddings 128-d vector | Lưu trong JSON dưới dạng `List[float]` |
| `classId` camelCase | Legacy endpoints dùng `ClassId` field |
| Bulk operations | `batch_create_employees()`, `bulk_sync()` |
| Export/Import face data | `FaceService.export_all()`, `FaceService.import_from_file()` |
| Avatar URL | Lấy từ `users.avatar_url`, không phải `students.avatar_url` |

### 7.2 Legacy Endpoints (`/api/*`)

Flutter dùng các endpoint trong `legacy_router.py` và các legacy routers. Các endpoint này sẽ được thay thế bởi v1 API (`/api/v1/*`) sau khi Flutter migrate.

### 7.3 Student Group vs Course

- **Student Group** (`student_groups`): Lớp hành chính/chủ quản — tương ứng với "Lớp" trên app
- **Course** (`courses`): Lớp học phần — giáo viên tạo để dạy

---

## Phụ Lục: Các Trường Đã Xóa (Migration 0014)

### Trường xóa khỏi `students`:
- `avatar_url` → dùng `users.avatar_url`
- `has_avatar` → derived từ `users.avatar_url IS NOT NULL`
- `attachment_id` → infrastructure
- `is_synced` → infrastructure
- `name` → dùng `users.full_name`
- `academic_class_id` → đổi thành `student_group_id`

### Trường xóa khỏi `teachers`:
- `avatar_url` → dùng `users.avatar_url`

### Bảng đổi tên:
- `academic_classes` → `student_groups`
- `classes` → `courses`
- `classroom_students` → `course_enrollments`

### Cột đổi tên:
- `classes.teacher_id` → `courses.instructor_id`
- `classes.class_name` → `courses.course_name`
- `sessions.classroom_id` → `sessions.course_id`
- `schedules.classroom_id` → `schedules.course_id`
- `devices.classroom_id` → `devices.course_id`
- `schedules.subject_name` → `schedules.room`
- `sessions.checkin_start_time` → `sessions.checkin_window_start`
- `sessions.checkin_end_time` → `sessions.checkin_window_end`
- `teachers.employee_code` → `teachers.teacher_id`
