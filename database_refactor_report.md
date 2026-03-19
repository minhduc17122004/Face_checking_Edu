# Báo Cáo Tái Cấu Trúc Database - Hệ Thống Điểm Danh Nhận Diện Khuôn Mặt AI

**Ngày:** 19/03/2026  
**Dự án:** Face Time Keeping - Flutter Attendance System  
**Phiên bản Database:** PostgreSQL

---

## 1. Tổng Quan

Báo cáo này ghi nhận việc tái cấu trúc database cho hệ thống điểm danh nhận diện khuôn mặt AI từ thiết kế đơn giản sang kiến trúc phân lớp, có khả năng mở rộng và sẵn sàng cho production.

### Mục tiêu đạt được:
- Giữ tương thích ngược với ứng dụng Flutter hiện tại
- Cải thiện khả năng mở rộng và rõ ràng kiến trúc
- Thêm các khái niệm cốt lõi còn thiếu (lịch, phiên, thiết bị)
- Hỗ trợ chống gian lận trong điểm danh

---

## 2. Kiến Trúc Database Mới

### 2.1 Sơ đồ Quan hệ Thực thể (ERD)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    USERS    │────▶│  TEACHERS   │     │  STUDENTS   │
│  (UUID PK)  │     │   (INT PK)  │     │  (INT PK)   │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                                │
                                                │
┌─────────────┐     ┌─────────────────┐        │
│  DEVICES    │◀────│ CLASSROOM_STUDENTS│◀─────┘
│ (UUID PK)   │     │   (UUID PK)     │
└──────┬──────┘     └────────┬────────┘
       │                     │
       │                     ▼
       │            ┌─────────────┐
       │            │ CLASSROOMS  │
       │            │ (UUID PK)   │
       │            └──────┬──────┘
       │                   │
       │     ┌─────────────┼─────────────┐
       │     │             │             │
       ▼     ▼             ▼             ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ SCHEDULES   │  │   SESSIONS  │  │  ATTENDANCE │
│ (UUID PK)   │  │  (UUID PK)  │  │  (UUID PK)  │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                 │                │
       │                 └────────┬───────┘
       │                          │
       └──────────────────────────┘
                    ┌─────────────┐
                    │ TIME_SLOTS  │
                    │  (INT PK)   │
                    └─────────────┘
```

### 2.2 Các Bảng Mới

| Bảng | Mô tả | Khóa chính |
|------|-------|------------|
| `time_slots` | Định nghĩa tiết học toàn cục | INT (auto) |
| `classroom_students` | Quan hệ nhiều-nhiều lớp-học sinh | UUID |
| `schedules` | Lịch học hàng tuần | UUID |
| `sessions` | Phiên điểm danh thực tế | UUID |
| `attendance` | Bản ghi điểm danh mới (thay thế logic cũ) | UUID |

### 2.3 Các Bảng Đã Sửa Đổi

| Bảng | Thay đổi |
|------|----------|
| `devices` | Thêm `classroom_id` FK |
| `classroom` | Thêm quan hệ với schedules, sessions, devices |
| `student` | Thêm quan hệ với classroom_enrollments, attendances |

---

## 3. Chi Tiết Các Bảng

### 3.1 TIME_SLOTS - Tiết Học

```sql
CREATE TABLE time_slots (
    id SERIAL PRIMARY KEY,
    period_number INTEGER NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Dữ liệu mặc định (8 tiết):**
- Tiết 1: 07:30 - 08:15
- Tiết 2: 08:20 - 09:05
- Tiết 3: 09:10 - 09:55
- Tiết 4: 10:00 - 10:45
- Tiết 5: 10:50 - 11:35
- Tiết 6: 13:00 - 13:45
- Tiết 7: 13:50 - 14:35
- Tiết 8: 14:40 - 15:25

### 3.2 CLASSROOM_STUDENTS - Lớp Học Sinh

```sql
CREATE TABLE classroom_students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    classroom_id UUID NOT NULL REFERENCES classes(id),
    student_id INTEGER NOT NULL REFERENCES students(id),
    enrolled_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(classroom_id, student_id)
);
```

**Đặc điểm:**
- Hỗ trợ quan hệ nhiều-nhiều
- Một học sinh có thể thuộc nhiều lớp
- Ngăn chặn đăng ký trùng lặp

### 3.3 SCHEDULES - Lịch Học

```sql
CREATE TABLE schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    classroom_id UUID NOT NULL REFERENCES classes(id),
    day_of_week INTEGER NOT NULL CHECK (1-7),
    time_slot_id INTEGER NOT NULL REFERENCES time_slots(id),
    subject_name VARCHAR(255),
    UNIQUE(classroom_id, day_of_week, time_slot_id)
);
```

**Đặc điểm:**
- Liên kết lớp học với ngày trong tuần và tiết học
- Ngăn chặn lịch trùng lặp

### 3.4 SESSIONS - Phiên Điểm Danh

```sql
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    classroom_id UUID NOT NULL REFERENCES classes(id),
    schedule_id UUID REFERENCES schedules(id),
    session_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME,
    status VARCHAR(20) CHECK ('scheduled', 'active', 'closed'),
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Trạng thái phiên:**
- `scheduled`: Được lên kế hoạch
- `active`: Đang điểm danh
- `closed`: Đã đóng

### 3.5 ATTENDANCE - Điểm Danh (Bảng Mới)

```sql
CREATE TABLE attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id),
    student_id INTEGER NOT NULL REFERENCES students(id),
    checkin_time TIMESTAMP NOT NULL,
    status VARCHAR(20) CHECK ('present', 'late', 'absent'),
    confidence FLOAT,
    device_id UUID REFERENCES devices(id),
    UNIQUE(session_id, student_id)
);
```

**Đặc điểm:**
- Ngăn chặn điểm danh trùng lặp
- Liên kết với phiên và thiết bị

---

## 4. Các File Đã Tạo

### 4.1 Models (SQLAlchemy)

| File | Mô tả |
|------|-------|
| `app/models/time_slot.py` | Model TimeSlot |
| `app/models/classroom_student.py` | Model ClassroomStudent |
| `app/models/schedule.py` | Model Schedule |
| `app/models/session.py` | Model Session |
| `app/models/attendance.py` | Model Attendance (mới) |

### 4.2 Schemas (Pydantic)

| File | Mô tả |
|------|-------|
| `app/schemas/time_slot_schema.py` | Schema cho TimeSlot |
| `app/schemas/classroom_student_schema.py` | Schema cho ClassroomStudent |
| `app/schemas/schedule_schema.py` | Schema cho Schedule |
| `app/schemas/session_schema.py` | Schema cho Session |
| `app/schemas/attendance_new_schema.py` | Schema cho Attendance mới |

### 4.3 Routers (API Endpoints)

| File | Endpoints |
|------|-----------|
| `app/routers/time_slot_router.py` | `GET/POST /time-slots` |
| `app/routers/classroom_student_router.py` | `POST/GET/DELETE /classroom-students` |
| `app/routers/schedule_router.py` | `POST/GET/DELETE /schedules` |
| `app/routers/session_router.py` | `POST/GET/PATCH/DELETE /sessions` |
| `app/routers/attendance_new_router.py` | `POST/GET/DELETE /attendance/new` |

### 4.4 Alembic Migrations

| File | Mô tả |
|------|-------|
| `alembic/versions/0003_expand_schema.py` | Tạo cấu trúc bảng mới |
| `alembic/versions/0004_migrate_attendance_data.py` | Di chuyển dữ liệu từ bảng cũ |

---

## 5. Chiến Lược Di Chuyển

### 5.1 Migration 0003 - Mở Rộng Schema

```bash
alembic upgrade head
```

Tạo:
- Bảng `time_slots` với 8 tiết mặc định
- Bảng `classroom_students`
- Bảng `schedules`
- Bảng `sessions`
- Bảng `attendance`
- Cột `classroom_id` trong `devices`
- Các index cần thiết

### 5.2 Migration 0004 - Di Chuyển Dữ Liệu

- Tạo `sessions` từ dữ liệu `attendance_records` hiện có
- Di chuyển điểm danh sang bảng `attendance` mới
- Đánh dấu `attendance_records` là bảng legacy

### 5.3 Tương Thích Ngược

- Bảng `attendance_records` được giữ lại
- API endpoints cũ vẫn hoạt động
- `students.id` vẫn là INTEGER (Flutter tương thích)

---

## 6. API Endpoints Mới

### 6.1 Time Slots
```
GET  /time-slots          - Danh sách tiết học
POST /time-slots          - Tạo tiết học mới
GET  /time-slots/{id}     - Chi tiết tiết học
```

### 6.2 Classroom Students
```
POST /classroom-students              - Đăng ký học sinh vào lớp
GET  /classroom-students              - Danh sách đăng ký
GET  /classroom-students?classroom_id=... - Lọc theo lớp
GET  /classroom-students?student_id=...   - Lọc theo học sinh
DELETE /classroom-students/{id}       - Xóa đăng ký
```

### 6.3 Schedules
```
POST /schedules             - Tạo lịch học
GET  /schedules             - Danh sách lịch học
GET  /schedules/{id}       - Chi tiết lịch học
DELETE /schedules/{id}      - Xóa lịch học
```

### 6.4 Sessions
```
POST /sessions              - Tạo phiên điểm danh
GET  /sessions              - Danh sách phiên
GET  /sessions/{id}        - Chi tiết phiên
PATCH /sessions/{id}       - Cập nhật trạng thái
GET  /sessions/{id}/summary - Thống kê điểm danh
DELETE /sessions/{id}      - Xóa phiên
```

### 6.5 Attendance (Mới)
```
POST /attendance/new        - Tạo bản ghi điểm danh
GET  /attendance/new/session/{id} - Điểm danh theo phiên
GET  /attendance/new/student/{id} - Điểm danh theo học sinh
DELETE /attendance/new/{id}       - Xóa bản ghi
GET  /attendance/new/summary/session/{id} - Thống kê
```

---

## 7. Chỉ Mục (Indexes)

| Index | Bảng | Cột |
|-------|------|-----|
| `idx_classroom_students_classroom` | classroom_students | classroom_id |
| `idx_classroom_students_student` | classroom_students | student_id |
| `idx_schedules_classroom` | schedules | classroom_id |
| `idx_schedules_day` | schedules | day_of_week |
| `idx_sessions_classroom_date` | sessions | (classroom_id, session_date) |
| `idx_sessions_status` | sessions | status |
| `idx_attendance_session` | attendance | session_id |
| `idx_attendance_student` | attendance | student_id |
| `idx_devices_classroom` | devices | classroom_id |

---

## 8. Tính Năng Chống Gian Lận

### 8.1 Ràng Buộc Thiết Bị
- Mỗi thiết bị được gán cho một lớp học cụ thể
- Ngăn chặn điểm danh từ thiết bị không được phép

### 8.2 Ngăn Điểm Danh Trùng Lặp
```sql
UNIQUE(session_id, student_id)
```
- Mỗi học sinh chỉ có thể điểm danh một lần trong mỗi phiên

### 8.3 Xác Minh Lớp Học
- Điểm danh phải được gắn với phiên hợp lệ
- Phiên phải thuộc về một lớp học cụ thể

---

## 9. Các File Đã Sửa Đổi

| File | Thay đổi |
|------|----------|
| `app/models/device.py` | Thêm `classroom_id`, quan hệ `attendance_records` |
| `app/models/classroom.py` | Thêm quan hệ `schedules`, `sessions`, `devices` |
| `app/models/student.py` | Thêm quan hệ `classroom_enrollments`, `attendances` |
| `app/models/__init__.py` | Export 5 model mới |
| `app/schemas/__init__.py` | Export 5 schema mới |
| `app/main.py` | Đăng ký 5 router mới |

---

## 10. Khuyến Nghị Tối Ưu Hóa

### 10.1 Partitioning cho Bảng Attendance
```sql
CREATE TABLE attendance (
    ...
) PARTITION BY RANGE (checkin_time);

CREATE TABLE attendance_2026_03 PARTITION OF attendance
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
```

### 10.2 Vector Search cho Face Embeddings
```sql
CREATE EXTENSION IF NOT EXISTS vector;

ALTER TABLE face_embeddings 
ALTER COLUMN embedding_data TYPE vector(128);

CREATE INDEX idx_face_embeddings_vector 
ON face_embeddings USING ivfflat (embedding_data vector_cosine_ops);
```

---

## 11. Cách Triển Khai

### Bước 1: Chạy Migration
```bash
cd backend
alembic upgrade head
```

### Bước 2: Xác Nhận Migration
```bash
alembic current
alembic history
```

### Bước 3: Kiểm Tra API
```bash
# Khởi động server
uvicorn app.main:app --reload

# Kiểm tra endpoint mới
curl http://localhost:8000/time-slots
curl http://localhost:8000/docs
```

---

## 12. Kết Luận

Việc tái cấu trúc đã hoàn thành với các kết quả:

- **Kiến trúc phân lớp**: Thời gian → Lịch → Phiên → Điểm danh
- **Tương thích ngược**: Flutter app tiếp tục hoạt động
- **Mở rộng**: Dễ dàng thêm tính năng mới
- **Chống gian lận**: Ràng buộc thiết bị, ngăn trùng lặp
- **Hiệu suất**: Index được tối ưu cho các truy vấn phổ biến

---

**Người thực hiện:** Claude AI  
**Ngày hoàn thành:** 19/03/2026
