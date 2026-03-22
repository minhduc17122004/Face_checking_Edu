# Báo Cáo Triển Khai Backend — Phase 0–7

> **Ngày cập nhật:** 2026-03-21
> **Dự án:** Face Time Keeping - Flutter Attendance System
> **Framework:** FastAPI + SQLAlchemy 2.x (async) + PostgreSQL + Alembic
> **Trạng thái:** Hoàn thành Phase 0 → Phase 7

---

## 1. Tổng Quan

Báo cáo này ghi nhận toàn bộ thay đổi triển khai backend trong 8 Phase, từ việc sửa lỗi đặt tên nền tảng (Phase 0) đến đăng ký module hoàn chỉnh (Phase 7). Toàn bộ thay đổi tuân thủ nguyên tắc:

- Chỉ dùng `deleted_at` cho soft delete (không dùng `is_deleted` cột)
- Nhất quán tên domain: `classroom` → `course`, `classroom_id` → `course_id`
- Hỗ trợ đồng thời **v1 API** (`/api/v1/*`) và **Legacy API** (Flutter tương thích)
- Authorization: RBAC (admin / teacher / student)

---

## 2. Phase 0 — Sửa Lỗi Đặt Tên Không Nhất Quán (CRITICAL)

### 2.1 Mục tiêu
Sửa lỗi đặt tên trên toàn bộ các tầng (model, schema, repository, router) để phản ánh tên cột thực tế trong database sau Migration 0014.

### 2.2 Các lỗi đã sửa

#### Schema
| File | Thay đổi |
|------|----------|
| `schemas/v1/session.py` | `classroom_id` → `course_id`; `checkin_start_time` → `checkin_window_start`; `checkin_end_time` → `checkin_window_end`; xóa `is_deleted` khỏi `SessionOut` |
| `schemas/v1/device.py` | `classroom_id` → `course_id`; xóa `is_deleted` khỏi `DeviceResponse` |
| `schemas/v1/schedule.py` | `classroom_id` → `course_id`; `subject_name` → `room` |
| `schemas/attendance_new_schema.py` | `classroom_name` → `course_name` trong `AttendanceWithDetails` |
| `schemas/session_schema.py` (legacy) | Như trên, xóa `is_deleted` khỏi `SessionOut` |
| `schemas/schedule_schema.py` (legacy) | Như trên, xóa `is_deleted` khỏi `ScheduleOut` |
| `schemas/device_schema.py` (legacy) | Như trên, xóa `is_deleted` khỏi `DeviceResponse` |

#### Repository
| File | Thay đổi |
|------|----------|
| `repositories/session_repository.py` | `Session.classroom` → `Session.course`; `get_by_classroom` → `get_by_course`; `classroom_id` → `course_id`; `checkin_start_time` → `checkin_window_start` |
| `repositories/_base.py` | `_active()`: `getattr(..., "is_deleted") == False` → `deleted_at.is_(None)`; `soft_delete()`: chỉ set `deleted_at` |
| `repositories/device_repository.py` | `get_by_classroom` → `get_by_course`; thêm `deleted_at.is_(None)` |
| `repositories/attendance_repository.py` | `Attendance.is_deleted == False` → `Attendance.deleted_at.is_(None)` |
| `repositories/schedule_repository.py` | `get_by_classroom_day` → `get_by_course_day`; `get_by_classroom` → `get_by_course`; `classroom_id` → `course_id`; `is_deleted == False` → `deleted_at.is_(None)` |

#### Router
| File | Thay đổi |
|------|----------|
| `routers/v1/sessions.py` | Import `CourseRepository` thay `ClassroomRepository`; đổi `classroom_id` → `course_id`; `check_classroom_owner` → `check_course_owner` |
| `routers/v1/devices.py` | `classroom_id` → `course_id` |
| `routers/v1/schedules.py` | `CourseRepository`; `req.classroom_id` → `req.course_id`; `subject_name` → `room` |
| `routers/v1/faces.py` | Endpoint `/classrooms/{classroom_id}/face-embeddings` → `/courses/{course_id}/face-embeddings`; `export_classroom_faces` → `export_course_faces` |
| `routers/session_router.py` (legacy) | Import alias `Classroom` → `Course`; `body.classroom_id` → `body.course_id`; `is_deleted == False` → `deleted_at.is_(None)` |
| `routers/schedule_router.py` (legacy) | Tương tự; sửa syntax error; cập nhật soft-delete |
| `routers/attendance_new_router.py` | `Student.is_deleted == False` → `deleted_at.is_(None)` |

#### Models
| File | Thay đổi |
|------|----------|
| `models/session.py` | Thêm `@property is_deleted`; thêm `@property attendance_mode`, `effective_checkin_window_start`, `effective_checkin_window_end` |
| `models/device.py`, `schedule.py`, `attendance.py`, `course.py`, `student.py`, `user.py` | Thêm `@property is_deleted` kế thừa từ `deleted_at` |

---

## 3. Phase 1 — Tạo Module Department

### 3.1 Mục tiêu
Tạo module quản lý phòng ban/khoa hoàn chỉnh, tách khỏi chuỗi `department` trong Teacher.

### 3.2 Các file mới

#### Model — `models/department.py`
- Bảng `departments`: `id` (UUID PK), `code` (unique), `name`, `description`, `deleted_at`, timestamps, `created_by`, `updated_by`
- Relationship: `teachers` (1:N với `Teacher`)
- Indexes: `ix_departments_code` (unique), `ix_departments_name`, `deleted_at`
- Property: `is_deleted` (delegate từ `deleted_at`)

#### Schema — `schemas/v1/department.py`
```python
DepartmentCreate(code, name, description)
DepartmentUpdate(name, description)
DepartmentOut(id, code, name, description, created_at, updated_at)
DepartmentWithStats(DepartmentOut + teacher_count)
DepartmentList(total, items)
```

#### Repository — `repositories/department_repository.py`
- `get_by_id`, `get_by_code`: soft-delete aware
- `list`: pagination, filtered by `deleted_at.is_(None)`
- `count_teachers`: đếm teacher thuộc department
- `create`, `update`, `soft_delete` (chỉ set `deleted_at`)

#### Service — `services/department_service.py`
- `create_department`: kiểm tra trùng `code`
- `get_department`, `list_departments`, `update_department`, `delete_department` (soft)
- `get_department_with_stats`: trả về kèm `teacher_count`

#### Router — `routers/v1/departments.py`
| Method | Endpoint | Mô tả |
|--------|----------|--------|
| `POST` | `/departments/` | Tạo phòng ban |
| `GET` | `/departments/` | Danh sách (pagination) |
| `GET` | `/departments/{id}` | Chi tiết |
| `PUT` | `/departments/{id}` | Cập nhật |
| `DELETE` | `/departments/{id}` | Soft delete |

#### Migration — `alembic/versions/0016_add_departments.py`
- Tạo bảng `departments`
- Tạo unique indexes trên `code`, `name`
- Index trên `deleted_at`

### 3.3 Đăng ký
- `models/__init__.py`: thêm `Department`
- `repositories/__init__.py`: thêm `DepartmentRepository`
- `services/__init__.py`: thêm `DepartmentService`
- `schemas/__init__.py`: thêm Department schemas
- `routers/v1/__init__.py`: thêm `departments_router`

---

## 4. Phase 2 — Tái Cấu Trúc Bảng Teachers

### 4.1 Mục tiêu
Chuyển `teachers.department` (chuỗi string) thành `teachers.department_id` (UUID FK) để quan hệ chuẩn hóa với bảng `departments`.

### 4.2 Model — `models/teacher.py`
- Thêm `department_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("departments.id"), nullable=True)`
- Thêm `department_rel: Mapped[Optional["Department"]] = relationship("Department", back_populates="teachers")`
- Thêm `department_name` property

### 4.3 Migration — `alembic/versions/0017_refactor_teachers_department.py`
1. Thêm cột `department_id` (nullable)
2. Migrate dữ liệu cũ: đọc `teachers.department` string → tạo/lookup `departments` → set `teachers.department_id`
3. Thêm FK constraint
4. Drop cột `department` cũ

### 4.4 Đăng ký
- Teacher schema/service/router đã sử dụng `department_id` (cập nhật ở Phase 7)

---

## 5. Phase 3 — Mở Rộng Courses Với Attendance Config

### 5.1 Mục tiêu
Thêm cấu hình điểm danh tùy chỉnh cho mỗi khóa học: chế độ điểm danh, thời gian trước/sau cho phép, phân quyền theo khoa.

### 5.2 Model — `models/course.py`
Thêm các trường:
- `attendance_mode: Mapped[str] = mapped_column(String(20), default="fixed", nullable=False)`
- `attendance_before_minutes: Mapped[int] = mapped_column(Integer, default=15, nullable=False)`
- `attendance_after_minutes: Mapped[int] = mapped_column(Integer, default=15, nullable=False)`
- `department_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("departments.id"), nullable=True)`

#### Attendance Mode
| Mode | Ý nghĩa |
|------|---------|
| `fixed` | Chỉ cho phép điểm danh trong khoảng `checkin_window_start` → `checkin_window_end` |
| `flexible` | Bỏ qua cửa sổ checkin — cho phép điểm danh bất cứ lúc nào sau khi session bắt đầu |
| `custom` | Dùng `attendance_before_minutes` / `attendance_after_minutes` để tính cửa sổ tự động |

### 5.3 Migration — `alembic/versions/0018_extend_courses_attendance_config.py`
- Thêm 4 cột: `attendance_mode`, `attendance_before_minutes`, `attendance_after_minutes`, `department_id`
- Thêm CHECK constraint: `attendance_mode IN ('fixed', 'flexible', 'custom')`
- Index trên `department_id`

---

## 6. Phase 4 — Tự Động Tạo Sessions (SessionGeneratorService)

### 6.1 Mục tiêu
Tự động tạo attendance sessions dựa trên Schedule + TimeSlot cho ngày cụ thể, áp dụng cấu hình attendance mode của từng Course.

### 6.2 Service — `services/session_generator_service.py`

#### Logic chính: `generate_sessions_for_date(target_date)`
1. Lấy toàn bộ Schedule active cho `target_date.weekday()`
2. Với mỗi Schedule: lấy Course, TimeSlot liên quan
3. Tính `session_start` = `target_date` + `TimeSlot.start_time`
4. Tính `session_end` = `target_date` + `TimeSlot.end_time`
5. Áp dụng attendance window dựa trên `Course.attendance_mode`:
   - **fixed**: `checkin_window_start` = `session_start - attendance_before_minutes`; `checkin_window_end` = `session_start + attendance_after_minutes`
   - **flexible**: `checkin_window_start` = `None`; `checkin_window_end` = `None` (mở toàn bộ)
   - **custom**: dùng `course.attendance_before_minutes` và `course.attendance_after_minutes`
6. Kiểm tra session đã tồn tại (theo `schedule_id` + `session_date`) → skip nếu đã có
7. Tạo `Session` với `status = "scheduled"`

#### Helper methods
- `_combine_date_time(d: date, t: time)`: ghép date + time thành timezone-aware datetime
- `_compute_checkin_window(session_start, course)`: tính cửa sổ check-in theo mode
- `_session_exists(schedule_id, session_date)`: kiểm tra trùng

### 6.3 Router — `routers/v1/sessions.py`
Endpoint mới:
| Method | Endpoint | Mô tả |
|--------|----------|--------|
| `POST` | `/v1/sessions/generate-daily` | Tạo sessions cho ngày (query: `date`) |

---

## 7. Phase 5 — Tăng Cường Kiểm Tra Điểm Danh (Anti-Cheat)

### 7.1 Mục tiêu
Mở rộng validation anti-cheat để tôn trọng attendance mode, kiểm tra enrollment, và sử dụng cửa sổ checkin động.

### 7.2 Model — `models/session.py` (mở rộng)
```python
@property
def attendance_mode(self) -> str:
    if self.course and hasattr(self.course, "attendance_mode"):
        return getattr(self.course, "attendance_mode", "fixed") or "fixed"
    return "fixed"

@property
def effective_checkin_window_start(self) -> datetime | None:
    if self.course and getattr(self.course, "attendance_mode", None) == "flexible":
        return None  # flexible: không giới hạn
    return self.checkin_window_start

@property
def effective_checkin_window_end(self) -> datetime | None:
    if self.course and getattr(self.course, "attendance_mode", None) == "flexible":
        return None  # flexible: không giới hạn
    return self.checkin_window_end
```

### 7.3 Service — `services/anti_cheat_service.py`

#### Validation methods mới / mở rộng
| Method | Mô tả |
|--------|--------|
| `validate_checkin_window` | Dùng `effective_checkin_window_start/End`; flexible mode bỏ qua kiểm tra cửa sổ |
| `validate_student_enrolled_in_course` | Mới: kiểm tra student có trong `CourseEnrollment` của session.course |
| `validate_teacher_belongs_to_department` | Mới: kiểm tra teacher thuộc department của course |
| `validate_device_for_session` | Dùng `device.course_id` thay `device.classroom_id` |
| `detect_duplicate_attendance` | Dùng `Attendance.deleted_at.is_(None)` |

### 7.4 Service — `services/attendance_service.py`

#### Tự động phát hiện trạng thái late
```python
if session and session.effective_checkin_window_end:
    late_threshold = session.start_time + timedelta(minutes=15)
    if checkin_time > late_threshold:
        auto_status = "late"
```

---

## 8. Phase 6 — Endpoint Check-in Thời Gian Thực

### 8.1 Mục tiêu
Cung cấp endpoint tối ưu cho thiết bị nhận diện khuôn mặt gọi khi có sinh viên điểm danh.

### 8.2 Schema — `schemas/v1/attendance.py`

```python
class CheckinRequest(BaseModel):
    student_id: int
    session_id: uuid.UUID
    device_id: uuid.UUID
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)

class CheckinResponse(BaseModel):
    attendance_id: uuid.UUID
    student_id: int
    status: Literal["present", "late"]
    checkin_time: datetime
    message: str
```

### 8.3 Service — `services/attendance_service.py`
```python
async def realtime_checkin(self, req: CheckinRequest) -> CheckinResponse:
    now = datetime.now(timezone.utc)  # Dùng server time
    record = await self.create_attendance(
        session_id=req.session_id,
        student_id=req.student_id,
        checkin_time=now,
        status="present",
        confidence=req.confidence,
        device_id=req.device_id,
    )
    return CheckinResponse(
        attendance_id=record.id,
        student_id=record.student_id,
        status=record.status,
        checkin_time=record.checkin_time,
        message=f"Check-in recorded as '{record.status}'.",
    )
```

### 8.4 Router — `routers/v1/attendance.py`
| Method | Endpoint | Mô tả |
|--------|----------|--------|
| `POST` | `/v1/attendance/checkin` | Check-in thời gian thực từ thiết bị |

---

## 9. Phase 7 — Đăng Ký Tất Cả Module Mới

### 9.1 Tổng hợp các module cần đăng ký

#### `models/__init__.py`
```python
from app.models.department import Department  # noqa: F401
# __all__: thêm "Department"
```

#### `repositories/__init__.py`
```python
from app.repositories.department_repository import DepartmentRepository  # noqa: F401
from app.repositories.teacher_repository import TeacherRepository  # noqa: F401
# __all__: thêm "DepartmentRepository", "TeacherRepository"
```

#### `services/__init__.py`
```python
from app.services.department_service import DepartmentService  # noqa: F401
from app.services.teacher_service import TeacherService  # noqa: F401
from app.services.session_generator_service import SessionGeneratorService  # noqa: F401
# __all__: thêm "DepartmentService", "TeacherService", "SessionGeneratorService"
```

#### `schemas/__init__.py`
```python
from app.schemas.v1.department import (
    DepartmentCreate, DepartmentUpdate, DepartmentOut,
    DepartmentWithStats, DepartmentList,
)  # noqa: F401
from app.schemas.v1.teacher import (
    TeacherOut, TeacherAssignDepartment, TeacherList,
)  # noqa: F401
from app.schemas.v1.attendance import (
    CheckinRequest, CheckinResponse,
)  # noqa: F401
```

#### `routers/v1/__init__.py`
```python
from app.routers.v1.departments import router as departments_router
from app.routers.v1.teachers import router as teachers_router

api_v1_router.include_router(departments_router)
api_v1_router.include_router(teachers_router)

# __all__: thêm "departments_router", "teachers_router"
```

---

## 10. Tổng Kết Các Thay Đổi

### 10.1 File mới tạo (8 file)
| File | Mô tả |
|------|--------|
| `models/department.py` | Department model |
| `schemas/v1/department.py` | Department Pydantic schemas |
| `schemas/v1/teacher.py` | Teacher v1 schemas |
| `schemas/v1/attendance.py` | CheckinRequest/Response |
| `repositories/department_repository.py` | Department database ops |
| `services/department_service.py` | Department business logic |
| `services/teacher_service.py` | Teacher business logic |
| `services/session_generator_service.py` | Auto-generate sessions |

### 10.2 Migration mới (3 file)
| Migration | Mô tả |
|-----------|--------|
| `0016_add_departments.py` | Tạo bảng departments |
| `0017_refactor_teachers_department.py` | teachers.department string → department_id FK |
| `0018_extend_courses_attendance_config.py` | Thêm attendance_mode, before/after minutes, department_id vào courses |

### 10.3 File sửa (25+ file)
- Models: session, device, attendance, schedule, course, student, user, teacher — thêm `is_deleted` property
- Schemas: session, device, schedule, attendance_new, v1/session, v1/device, v1/schedule, v1/attendance
- Repositories: _base, session, device, attendance, schedule, user
- Routers: v1/sessions, v1/devices, v1/schedules, v1/faces, v1/attendance, legacy routers
- Services: attendance_service, anti_cheat_service
- Init files: models, repositories, services, schemas, routers/v1

### 10.4 Tổng số Alembic migration: 0016 → 0018
### 10.5 Tổng số bảng database: 14 bảng (thêm departments)

---

## 11. Kiến Trúc Cuối Cùng

### v1 API Endpoints (`/api/v1/*`)
| Prefix | Resource |
|--------|----------|
| `/api/v1/auth` | Authentication (login, register, refresh) |
| `/api/v1/users` | User management |
| `/api/v1/students` | Student profiles |
| `/api/v1/courses` | Course management |
| `/api/v1/attendance` | Attendance (create, query, summary, **checkin**) |
| `/api/v1/devices` | Device registration |
| `/api/v1/sessions` | Sessions (CRUD, **generate-daily**) |
| `/api/v1/schedules` | Schedule management |
| `/api/v1/time-slots` | Time slot configuration |
| `/api/v1/course-enrollments` | Enrollment management |
| `/api/v1/student-groups` | Student group management |
| `/api/v1/faces` | Face embedding export |
| `/api/v1/departments` | **Mới** — Department management |
| `/api/v1/teachers` | **Mới** — Teacher + department assignment |

### Anti-Cheat Pipeline (cho mỗi check-in)
1. ✅ Session auto-transition (scheduled→active, active→closed)
2. ✅ Session tồn tại và đang active
3. ✅ Student tồn tại
4. ✅ Student đăng ký trong Course
5. ✅ Device thuộc Course của session
6. ✅ Check-in trong cửa sổ cho phép (theo attendance_mode)
7. ✅ Không trùng lặp (session + student)

> **Ngày hoàn thành:** 2026-03-21
> **Trạng thái:** ✅ Tất cả 8 Phase hoàn thành
