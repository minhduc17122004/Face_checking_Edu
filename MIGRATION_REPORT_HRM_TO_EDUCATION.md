# HRM系统到教育系统迁移报告

> 生成日期: 2026-03-20  
> 项目: Face Time Keeping (HRM → Education)  
> 目标: 记录所有从HRM（人力资源管理）到Education（教育管理系统）的变更，为Native端调整提供参考

---

## 目录

1. [系统概述](#1-系统概述)
2. [后端模型变更](#2-后端模型变更)
3. [后端路由变更](#3-后端路由变更)
4. [后端Schemas变更](#4-后端schemas变更)
5. [后端服务变更](#5-后端服务变更)
6. [Flutter实体/模型变更](#6-flutter实体模型变更)
7. [Flutter页面变更](#7-flutter页面变更)
8. [API端点变更](#8-api端点变更)
9. [数据库变更](#9-数据库变更)
10. [数据关系图](#10-数据关系图)
11. [Native端调整要点](#11-native端调整要点)
12. [迁移检查清单](#12-迁移检查清单)

---

## 1. 系统概述

### 1.1 迁移背景

将原本用于**企业人力资源管理（HRM）**的考勤系统改造为**教育机构**的考勤系统。

### 1.2 核心概念对比

| HRM概念 | Education概念 | 说明 |
|---------|---------------|------|
| Employee (员工) | Student (学生) | 主要考勤对象 |
| Department (部门) | StudentGroup (行政班级) | 组织单位 |
| Classroom (教室) | Course (课程/教学班) | 教师创建的课程 |
| Check-in/out | Check-in/out | 考勤机制不变 |

### 1.3 迁移范围

```
Backend (Python/FastAPI)
├── Models: 7个重命名/新增, 3个删除
├── Routers: 4个新增, 3个删除
├── Schemas: 4个新增, 3个删除
├── Services: 2个新增, 1个别名
└── Legacy API: 保持Flutter兼容

Frontend (Flutter)
├── Entities: 4个新增, 4个删除
├── Pages: Employee相关 → Student相关
├── BLoCs: 重命名为Student BLoCs
└── API Service: 端点重命名

Database (PostgreSQL)
├── Tables: 3个重命名
├── Constraints: 强化1:1关系
└── 字段: 冗余字段移除
```

---

## 2. 后端模型变更

### 2.1 删除的模型

| 文件 | 表名 | 删除原因 |
|------|------|----------|
| `academic_class.py` | `academic_classes` | 概念混淆，用StudentGroup替代 |
| `classroom.py` | `classes` | 概念混淆，用Course替代 |
| `classroom_student.py` | `classroom_students` | 关系重构，用CourseEnrollment替代 |

### 2.2 新增的模型

#### Student模型 (新增)

**文件**: `backend/app/models/student.py`

```python
class Student(Base):
    __tablename__ = "students"

    # 主键: INT类型 (Flutter兼容性)
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)

    # 严格1:1关联User
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,      # UNIQUE约束
        nullable=False,   # NOT NULL约束
        index=True,
    )

    # 学号 (MSSV)
    student_code: Mapped[Optional[str]] = mapped_column(
        String(50), unique=True, nullable=True
    )

    # PIN码 (离线认证)
    pin: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)

    # 关联行政班级
    student_group_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("student_groups.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # 时间戳
    created_at: Mapped[datetime]
    updated_at: Mapped[datetime]
    deleted_at: Mapped[Optional[datetime]]  # 软删除

    # 审计字段
    created_by: Mapped[Optional[uuid.UUID]]
    updated_by: Mapped[Optional[uuid.UUID]]

    # 关系
    user: Mapped["User"] = relationship(back_populates="student_profile")
    student_group: Mapped[Optional["StudentGroup"]] = relationship(back_populates="students")
    course_enrollments: Mapped[List["CourseEnrollment"]]
    face_embeddings: Mapped[List["FaceEmbedding"]]
    attendances: Mapped[List["Attendance"]]
```

**关键属性**:

```python
@property
def name(self) -> Optional[str]:
    """从User模型获取姓名（向后兼容）"""
    return self.user.full_name if self.user else None

@property
def avatar_url(self) -> Optional[str]:
    """从User模型获取头像URL"""
    return self.user.avatar_url if self.user else None

@property
def has_avatar(self) -> bool:
    """判断是否有头像（派生属性）"""
    return self.user.avatar_url is not None if self.user else False
```

**移除的冗余字段**:

- `avatar_url` → 现在存储在 `users.avatar_url`
- `has_avatar` → 派生自 `users.avatar_url IS NOT NULL`
- `attachment_id` → 基础设施层，不需要
- `is_synced` → 基础设施层，不需要
- `name` → 现在存储在 `users.full_name`

#### Course模型 (原Classroom)

**文件**: `backend/app/models/course.py`

```python
class Course(Base):
    """课程/教学班 - 由教师创建和管理"""

    __tablename__ = "courses"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(255))
    course_code: Mapped[Optional[str]] = mapped_column(String(50), unique=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # 授课教师 (1:1关联Teacher)
    instructor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("teachers.id", ondelete="CASCADE"),
        nullable=False,
    )

    # 时间槽
    time_slot_ids: Mapped[List[uuid.UUID]] = mapped_column(
        ARRAY(UUID(as_uuid=True)), nullable=True
    )

    # 状态
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # 审计
    created_at: Mapped[datetime]
    updated_at: Mapped[datetime]
    deleted_at: Mapped[Optional[datetime]]

    # 关系
    instructor: Mapped["Teacher"] = relationship(back_populates="courses")
    enrollments: Mapped[List["CourseEnrollment"]] = relationship(
        back_populates="course", cascade="all, delete-orphan"
    )
    schedules: Mapped[List["Schedule"]] = relationship(back_populates="course")
    sessions: Mapped[List["Session"]] = relationship(back_populates="course")
```

#### CourseEnrollment模型 (原ClassroomStudent)

**文件**: `backend/app/models/course_enrollment.py`

```python
class CourseEnrollment(Base):
    """课程-学生多对多关联"""

    __tablename__ = "course_enrollments"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    course_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("courses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    student_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    enrolled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(String(20), default="active")

    # UNIQUE约束: 每个学生每个课程只能有一个注册记录
    __table_args__ = (
        UniqueConstraint('course_id', 'student_id', name='uq_course_student'),
    )

    # 关系
    course: Mapped["Course"] = relationship(back_populates="enrollments")
    student: Mapped["Student"] = relationship(back_populates="course_enrollments")
```

#### StudentGroup模型 (原AcademicClass)

**文件**: `backend/app/models/student_group.py`

```python
class StudentGroup(Base):
    """行政班级（如48K21.1）- 学生归属的行政单位"""

    __tablename__ = "student_groups"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(255))  # 如 "48K21.1"
    code: Mapped[Optional[str]] = mapped_column(String(50), unique=True)
    grade_level: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    academic_year: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)

    # 班主任 (关联Teacher)
    advisor_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("teachers.id", ondelete="SET NULL"),
        nullable=True,
    )

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime]
    updated_at: Mapped[datetime]
    deleted_at: Mapped[Optional[datetime]]

    # 关系
    advisor: Mapped[Optional["Teacher"]] = relationship(back_populates="advised_groups")
    students: Mapped[List["Student"]] = relationship(back_populates="student_group")
```

### 2.3 模型重命名映射表

| 旧名称 (HRM) | 新名称 (Education) | 表名变更 |
|--------------|-------------------|----------|
| `AcademicClass` | `StudentGroup` | `academic_classes` → `student_groups` |
| `Classroom` | `Course` | `classes` → `courses` |
| `ClassroomStudent` | `CourseEnrollment` | `classroom_students` → `course_enrollments` |
| `Employee` | `Student` | 无对应表，通过User+Student实现 |
| `Department` | `StudentGroup` | 同上 |

### 2.4 修改的模型

#### User模型变更

**文件**: `backend/app/models/user.py`

```python
class User(Base):
    """中央认证表 - 所有用户（Student/Teacher）的统一认证入口"""

    __tablename__ = "users"

    # 角色约束: 仅允许三种角色
    role: Mapped[str] = mapped_column(
        String(20),
        default="student",
        nullable=False,
    )
    # roles表引用被移除

    # 单一真实来源: 头像URL
    avatar_url: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True
    )

    # 关系重命名
    courses = relationship("Course", back_populates="instructor")
    # classes = relationship(...)  # 已移除

    advised_groups = relationship("StudentGroup", back_populates="advisor")
    # advised_classes = relationship(...)  # 已移除

    student_profile: Mapped[Optional["Student"]] = relationship(
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )
```

#### Teacher模型变更

**文件**: `backend/app/models/teacher.py`

```python
class Teacher(Base):
    """教师档案 - 1:1关联User"""

    __tablename__ = "teachers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)

    # 强化1:1关系
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,      # 新增UNIQUE约束
        nullable=False,    # 新增NOT NULL约束
    )

    # 保留字段
    employee_code: Mapped[Optional[str]] = mapped_column(String(50))

    # 关系
    user: Mapped["User"] = relationship(back_populates="teacher_profile")
    courses: Mapped[List["Course"]] = relationship(back_populates="instructor")
    advised_groups: Mapped[List["StudentGroup"]] = relationship(back_populates="advisor")
```

#### Attendance模型变更

**文件**: `backend/app/models/attendance.py`

```python
class Attendance(Base):
    """考勤记录 - 现在关联Student (INT主键)"""

    student_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # 原: employee_id → 现: student_id

    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    status: Mapped[str] = mapped_column(String(20))
    check_in_time: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    check_out_time: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))

    # 关系
    student: Mapped["Student"] = relationship(back_populates="attendances")
```

### 2.5 保留的核心模型

以下模型在迁移中未做变更：

| 模型 | 表名 | 说明 |
|------|------|------|
| `FaceEmbedding` | `face_embeddings` | 人脸特征向量 |
| `Session` | `sessions` | 考勤会话 |
| `TimeSlot` | `time_slots` | 时间段 |
| `Schedule` | `schedules` | 课程时间表 |
| `Device` | `devices` | 设备注册表 |
| `RefreshToken` | `refresh_tokens` | 认证令牌 |

---

## 3. 后端路由变更

### 3.1 路由文件变更

#### 删除的路由

| 文件 | 端点前缀 |
|------|----------|
| `academic_class_router.py` | `/academic-classes` |
| `classroom_router.py` | `/classrooms` |
| `classroom_student_router.py` | `/classroom-students` |

#### 删除的V1路由

| 文件 | 端点前缀 |
|------|----------|
| `v1/academic_classes.py` | `/v1/academic-classes` |
| `v1/classrooms.py` | `/v1/classrooms` |
| `v1/classroom_students.py` | `/v1/classroom-students` |

#### 新增的路由

| 文件 | 端点前缀 | 说明 |
|------|----------|------|
| `student_router.py` | `/students` | 学生CRUD |
| `course_router.py` | `/courses` | 课程管理 |
| `course_enrollment_router.py` | `/course-enrollments` | 选课管理 |
| `student_group_router.py` | `/student-groups` | 行政班级管理 |

#### 新增的V1路由

| 文件 | 端点前缀 | 说明 |
|------|----------|------|
| `v1/students.py` | `/v1/students` | 学生REST API |
| `v1/courses.py` | `/v1/courses` | 课程REST API |
| `v1/course_enrollments.py` | `/v1/course-enrollments` | 选课REST API |
| `v1/student_groups.py` | `/v1/student-groups` | 行政班级REST API |

### 3.2 V1路由聚合 (`backend/app/routers/v1.py`)

```python
# 新的路由导入
from app.routers.v1.students import router as students_router
from app.routers.v1.courses import router as courses_router
from app.routers.v1.course_enrollments import router as course_enrollments_router
from app.routers.v1.student_groups import router as student_groups_router

# 路由聚合
app.include_router(students_router, prefix="/api/v1", tags=["Students"])
app.include_router(courses_router, prefix="/api/v1", tags=["Courses"])
app.include_router(course_enrollments_router, prefix="/api/v1", tags=["Course Enrollments"])
app.include_router(student_groups_router, prefix="/api/v1", tags=["Student Groups"])
```

### 3.3 遗留路由 (`backend/app/routers/legacy_router.py`)

为Flutter应用提供向后兼容的API端点：

```python
# 学生相关端点
@router.post("/api/student/get_all_students")
async def get_all_students(request: Request):
    """获取所有学生列表 - Flutter遗留API"""

@router.post("/api/student/create")
async def create_student(request: Request):
    """创建单个学生 - Flutter遗留API"""

@router.post("/api/student/create/batch")
async def create_student_batch(request: Request):
    """批量创建学生 - Flutter遗留API"""

@router.post("/api/student/avatars/upload")
async def upload_student_avatar(request: Request):
    """上传学生头像 - Flutter遗留API"""

@router.post("/api/student/export/json")
async def export_student_faces(request: Request):
    """导出人脸数据JSON - Flutter遗留API"""

@router.post("/api/student/update/embedding")
async def update_student_embedding(request: Request):
    """更新人脸特征向量 - Flutter遗留API"""

# 考勤相关端点
@router.post("/api/attendance/history/sync_bulk_io")
async def sync_bulk_attendance(request: Request):
    """批量同步考勤记录 - Flutter遗留API"""
```

---

## 4. 后端Schemas变更

### 4.1 新增的Schemas

| 文件 | 说明 |
|------|------|
| `student_schema.py` | Student创建/更新/响应Schema |
| `course_schema.py` | Course创建/更新/响应Schema |
| `course_enrollment_schema.py` | CourseEnrollment Schema |
| `student_group_schema.py` | StudentGroup Schema |

### 4.2 StudentSchema (`backend/app/schemas/student_schema.py`)

#### 现代REST API Schema

```python
# 创建学生请求
class StudentCreate(BaseModel):
    user_id: Optional[UUID]
    student_code: Optional[str]
    pin: Optional[str]
    student_group_id: Optional[UUID]

# 学生响应
class StudentResponse(BaseModel):
    id: int
    user_id: UUID
    student_code: Optional[str]
    name: str  # 从User派生
    avatar_url: Optional[str]  # 从User派生
    student_group_id: Optional[UUID]
    has_avatar: bool  # 派生属性
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
```

#### Flutter遗留API Schema

```python
# Flutter遗留格式 - 使用camelCase
class StudentOutLegacy(BaseModel):
    id: int
    name: str
    pin: Optional[str]
    jobTitle: Optional[str]  # Flutter用camelCase
    hasAvatar: bool
    avatarUrl: Optional[str]
    attachmentId: Optional[str]
    studentCode: Optional[str]
    studentGroupId: Optional[str]
    studentGroupName: Optional[str]

    @classmethod
    def from_orm(cls, student: Student) -> "StudentOutLegacy":
        """从ORM模型转换"""
        return cls(
            id=student.id,
            name=student.name or "",
            pin=student.pin,
            jobTitle=student.student_group.name if student.student_group else None,
            hasAvatar=student.has_avatar,
            avatarUrl=student.avatar_url,
            # ...
        )
```

### 4.3 CourseSchema (`backend/app/schemas/course_schema.py`)

```python
class CourseCreate(BaseModel):
    name: str
    course_code: Optional[str]
    description: Optional[str]
    instructor_id: UUID
    time_slot_ids: Optional[List[UUID]]
    is_active: bool = True

class CourseResponse(BaseModel):
    id: UUID
    name: str
    course_code: Optional[str]
    instructor_id: UUID
    enrollment_count: int  # 派生字段
    created_at: datetime

    class Config:
        from_attributes = True
```

### 4.4 CourseEnrollmentSchema (`backend/app/schemas/course_enrollment_schema.py`)

```python
class CourseEnrollmentCreate(BaseModel):
    course_id: UUID
    student_id: int
    status: str = "active"

class CourseEnrollmentResponse(BaseModel):
    id: UUID
    course_id: UUID
    student_id: int
    enrolled_at: datetime
    status: str
    course_name: Optional[str]  # 派生
    student_name: Optional[str]  # 派生

    class Config:
        from_attributes = True
```

### 4.5 StudentGroupSchema (`backend/app/schemas/student_group_schema.py`)

```python
class StudentGroupCreate(BaseModel):
    name: str  # 如 "48K21.1"
    code: Optional[str]
    grade_level: Optional[int]
    academic_year: Optional[str]
    advisor_id: Optional[UUID]

class StudentGroupResponse(BaseModel):
    id: UUID
    name: str
    code: Optional[str]
    grade_level: Optional[int]
    academic_year: Optional[str]
    advisor_id: Optional[UUID]
    advisor_name: Optional[str]  # 派生
    student_count: int  # 派生字段

    class Config:
        from_attributes = True
```

### 4.6 删除的Schemas

| 文件 | 原因 |
|------|------|
| `academic_class_schema.py` | 被StudentGroupSchema替代 |
| `classroom_schema.py` | 被CourseSchema替代 |
| `classroom_student_schema.py` | 被CourseEnrollmentSchema替代 |

---

## 5. 后端服务变更

### 5.1 新增服务

#### StudentService (`backend/app/services/student_service.py`)

```python
class StudentService:
    """学生业务逻辑服务"""

    def __init__(self, db: Session):
        self.db = db

    async def create_student(self, data: StudentCreate) -> Student:
        """创建学生档案"""

    async def get_student(self, student_id: int) -> Optional[Student]:
        """获取学生详情"""

    async def get_all_students(
        self,
        skip: int = 0,
        limit: int = 100,
        student_group_id: Optional[UUID] = None,
    ) -> List[Student]:
        """获取所有学生（支持分页和过滤）"""

    async def update_student(
        self, student_id: int, data: StudentUpdate
    ) -> Optional[Student]:
        """更新学生信息"""

    async def delete_student(self, student_id: int) -> bool:
        """软删除学生"""

    async def get_student_by_user_id(self, user_id: UUID) -> Optional[Student]:
        """通过User ID获取学生"""

    async def get_student_by_pin(self, pin: str) -> Optional[Student]:
        """通过PIN码查找学生（离线认证）"""

    # Flutter兼容方法
    async def get_legacy_students(self) -> List[StudentOutLegacy]:
        """获取Flutter遗留格式的学生列表"""

    async def create_students_batch(
        self, students_data: List[StudentCreate]
    ) -> BatchStudentResponse:
        """批量创建学生"""
```

#### CourseService (`backend/app/services/course_service.py`)

```python
class CourseService:
    """课程业务逻辑服务"""

    async def create_course(self, data: CourseCreate) -> Course:
        """创建课程"""

    async def get_course(self, course_id: UUID) -> Optional[Course]:
        """获取课程详情"""

    async def get_courses_by_instructor(
        self, instructor_id: UUID
    ) -> List[Course]:
        """获取教师的所有课程"""

    async def enroll_student(
        self, course_id: UUID, student_id: int
    ) -> CourseEnrollment:
        """学生选课"""

    async def unenroll_student(
        self, course_id: UUID, student_id: int
    ) -> bool:
        """学生退课"""

    async def get_course_students(
        self, course_id: UUID
    ) -> List[Student]:
        """获取课程的选课学生"""
```

### 5.2 服务导出变更 (`backend/app/services/__init__.py`)

```python
# 新的服务导出
from app.services.student_service import StudentService
from app.services.course_service import CourseService

# 保留的服务
from app.services.auth_service import AuthService
from app.services.user_service import UserService
from app.services.attendance_service import AttendanceService
from app.services.face_service import FaceService
from app.services.device_service import DeviceService

# 别名（向后兼容）
ClassroomService = CourseService  # ClassroomService → CourseService
```

### 5.3 删除的服务

| 文件 | 原因 |
|------|------|
| `classroom_service.py` | 重命名为 `course_service.py` |

---

## 6. Flutter实体/模型变更

### 6.1 新增的实体

#### Student实体 (`lib/entities/student.dart`)

```dart
class Student {
  final int id;           // INT主键（与后端Student.id对应）
  final String? pin;       // PIN码
  final String name;       // 姓名（从User派生）
  final dynamic jobTitle;  // 班级名（原职位字段，重命名语义）
  final bool hasAvatar;    // 是否有头像
  final String? avatar;   // 头像URL

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as int,
      pin: json['pin'] is String ? json['pin'] as String : null,
      name: json['name'] as String,
      jobTitle: json['job_title'],  // 原job_title用于显示班级
      hasAvatar: json['has_avatar'] as bool? ?? false,
      avatar: json['avatar_url'] is String ? json['avatar_url'] as String : null,
    );
  }

  Person toPerson() {
    return Person(
      studentId: id,
      pin: pin,
      name: name,
      jobTitle: jobTitle,
      updatedTime: DateTime.now(),
    );
  }
}
```

#### RegisterStudent实体 (`lib/entities/register_student.dart`)

```dart
class RegisterStudent {
  final int? id;
  final String? pin;
  final String name;
  final String? jobTitle;  // 班级
  final String? attachmentId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pin': pin,
      'name': name,
      'job_title': jobTitle,
      'attachment_id': attachmentId,
    };
  }
}
```

#### VerifyStudent实体 (`lib/entities/verify_student.dart`)

```dart
class VerifyStudent {
  final int studentId;
  final String? pin;
  final String? name;
  final String? jobTitle;

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'pin': pin,
      'name': name,
      'job_title': jobTitle,
    };
  }
}
```

### 6.2 删除的实体

| 文件 | 说明 |
|------|------|
| `employee.dart` | 员工实体 - 已删除 |
| `register_employee.dart` | 注册员工请求 - 已删除 |
| `verify_employee.dart` | 验证员工请求 - 已删除 |
| `create_employee_response.dart` | 创建员工响应 - 已删除 |
| `create_employees_model.dart` | 创建员工模型 - 已删除 |

### 6.3 新增的数据模型

#### StudentRequest (`lib/data/models/student_request.dart`)

```dart
// 单个学生请求
class StudentRequest {
  final int? id;
  final String? pin;
  final String name;
  final String? jobTitle;  // 班级
  final String? attachmentId;

  Map<String, dynamic> toJson() => {...};
}

// 批量创建请求
class CreateStudentBatchRequest {
  final List<StudentRequest> students;

  Map<String, dynamic> toJson() => {
    'students': students.map((s) => s.toJson()).toList(),
  };
}
```

#### BatchStudentResponse (`lib/data/models/batch_student_response.dart`)

```dart
class BatchStudentResponse {
  final List<Student> students;
  final List<StudentError> errors;
  final int successCount;
  final int errorCount;

  factory BatchStudentResponse.fromJson(Map<String, dynamic> json) {
    return BatchStudentResponse(
      students: (json['students'] as List?)
          ?.map((s) => Student.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      errors: (json['errors'] as List?)
          ?.map((e) => StudentError.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      successCount: json['success_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? 0,
    );
  }
}
```

### 6.4 Person实体变更 (`lib/entities/person.dart`)

```dart
class Person {
  final int studentId;     // 原: employeeId
  final String? pin;
  final String name;
  final dynamic jobTitle;   // 原: jobTitle（语义改为班级）
  final DateTime updatedTime;

  // toJson/toHive用于Hive本地存储
}
```

---

## 7. Flutter页面变更

### 7.1 EmployeeBloc变更 (`lib/pages/employee/blocs/employee_bloc.dart`)

#### 事件重命名

| 旧事件 | 新事件 | 说明 |
|--------|--------|------|
| `RegisterEmployee` | `RegisterStudent` | 注册学生 |
| `RemoveEmployee` | `RemoveStudent` | 删除学生 |
| `FetchEmployees` | `FetchStudents` | 获取学生列表 |

#### 事件监听变更

```dart
// 原: EmployeeEvent → 新: StudentEvent
listenEvent<DidChangeStudentEvent>((e) => _didUpdateStudent(e.student));
listenEvent<SyncStudentEvent>((e) => _onSyncStudentComplete(e));
```

#### 核心方法变更

```dart
// _fetchEmployees() → _fetchStudents()
Future<void> _fetchStudents() async {
  emit(state.copyWith(serverStatus: DataSourceStatus.loading));

  final result = await userService.getStudents();  // 原: getEmployees()

  if (result is DataSuccess) {
    // 保存到本地Hive
    await hiveService.savePersons(result.data!);
    emit(state.copyWith(
      studentsFromServer: result.data,  // 原: employeesFromServer
      serverStatus: DataSourceStatus.success,
    ));
  }
}

// registerStudent() → onRegisterStudent()
Future<void> onRegisterStudent(RegisterStudent data) async {
  // 注册学生
}

// removeStudent() → onRemoveStudent()
Future<void> onRemoveStudent(int studentId) async {
  // 删除学生
}
```

### 7.2 EmployeeState变更 (`lib/pages/employee/blocs/employee_state.dart`)

```dart
class EmployeeState {
  final List<Student>? students;           // 本地学生列表
  final List<Student>? studentsFromServer; // 服务器学生列表
  final DataSourceStatus status;
  final DataSourceStatus serverStatus;
  final String? error;
  final bool isSyncing;
}
```

### 7.3 EmployeePage变更 (`lib/pages/employee/employee_page.dart`)

#### 页面标题变更

```dart
// 原: "Nhân Viên" → 新: "Học Sinh"
AppBar(title: Text('Học Sinh', ...))
```

#### 添加学生对话框变更

```dart
// 原: AddEmployeeDialog → 新: AddStudentDialog
onPressed: () => showDialog(
  context: context,
  builder: (_) => AddStudentDialog(hasServerConfig: hasServerConfig),
)
```

#### 同步操作变更

```dart
// 原: syncEmployees() → 新: syncStudents()
onPressed: () => context.read<EmployeeBloc>().add(SyncStudentEvent()),
```

### 7.4 新增AddStudentDialog (`lib/pages/employee/add_student_dialog.dart`)

```dart
class AddStudentDialog extends StatefulWidget {
  final bool hasServerConfig;

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  // 表单字段
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  String? _selectedClass;  // 原: jobTitle → 新: class

  // 班级列表（从StudentGroup获取）
  List<String> _classes = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Thêm Học Sinh Mới'),  // "添加新学生"
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 学生姓名
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Tên Học Sinh',  // "学生姓名"
            ),
          ),
          // 班级
          DropdownButtonFormField<String>(
            value: _selectedClass,
            items: _classes.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c),
            )).toList(),
            onChanged: (value) => setState(() => _selectedClass = value),
          ),
          // PIN码
          TextField(
            controller: _pinController,
            decoration: InputDecoration(
              labelText: 'Mã PIN',  // "PIN码"
            ),
          ),
        ],
      ),
      actions: [...],
    );
  }
}
```

---

## 8. API端点变更

### 8.1 API端点定义 (`lib/data/remote/api_endpoint.dart`)

```dart
class ApiEndpoint {
  // 学生相关端点（新增）
  static const String students = '/api/student/get_all_students';
  static const String student = '/student';
  static const String registerStudent = "/api/student/create";
  static const String registerStudentBatch = "/api/student/create/batch";
  static const String uploadStudentAvatar = "/api/student/avatars/upload";
  static const String exportStudentFaces = "/api/student/export/json";
  static const String updateStudentEmbedding = "/api/student/update/embedding";

  // 移除的端点
  // static const String employees = '/api/employee/...';  // 已移除
  // static const String registerEmployee = "/api/employee/...";  // 已移除
}
```

### 8.2 UserService变更 (`lib/data/remote/user_service.dart`)

#### 方法重命名

| 旧方法 | 新方法 | 说明 |
|--------|--------|------|
| `getEmployees()` | `getStudents()` | 获取学生列表 |
| `registerEmployee()` | `registerStudent()` | 注册学生 |
| `registerEmployees()` | `registerStudents()` | 批量注册学生 |
| `deleteEmployee()` | `deleteStudent()` | 删除学生 |

#### 方法签名

```dart
class UserService {
  // 获取学生列表
  Future<DataState<List<Student>>> getStudents() async {
    try {
      final response = await apiClient.post(
        ApiEndpoint.students,
        data: {},
      );
      // 解析Student列表
      final List<Student> students = (response.data['students'] as List)
          .map((json) => Student.fromJson(json))
          .toList();
      return DataSuccess(students);
    } catch (e) {
      return DataFailed(e.toString());
    }
  }

  // 注册学生
  Future<DataState<Student>> registerStudent(RegisterStudent data) async {
    final response = await apiClient.post(
      ApiEndpoint.registerStudent,
      data: data.toJson(),
    );
    return DataSuccess(Student.fromJson(response.data));
  }

  // 批量注册学生
  Future<DataState<BatchStudentResponse>> registerStudents(
    CreateStudentBatchRequest data,
  ) async {
    final response = await apiClient.post(
      ApiEndpoint.registerStudentBatch,
      data: data.toJson(),
    );
    return DataSuccess(BatchStudentResponse.fromJson(response.data));
  }
}
```

---

## 9. 数据库变更

### 9.1 表重命名SQL

```sql
-- AcademicClass → StudentGroup
ALTER TABLE academic_classes RENAME TO student_groups;

-- Classroom → Course (classes表)
ALTER TABLE classes RENAME TO courses;

-- ClassroomStudent → CourseEnrollment
ALTER TABLE classroom_students RENAME TO course_enrollments;
```

### 9.2 列重命名

```sql
-- courses表
ALTER TABLE courses RENAME COLUMN instructor_id TO teacher_id;
-- 注意: 实际保留instructor_id（教师字段）

-- course_enrollments表
ALTER TABLE course_enrollments RENAME COLUMN classroom_id TO course_id;
ALTER TABLE course_enrollments RENAME COLUMN student_id TO student_id;  -- 类型变更
-- student_id从UUID变更为INT

-- students表
ALTER TABLE students RENAME COLUMN academic_class_id TO student_group_id;
```

### 9.3 约束强化

```sql
-- 强化1:1关系 - students.user_id NOT NULL + UNIQUE
ALTER TABLE students
ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE students
ADD CONSTRAINT students_user_id_key UNIQUE;

-- 强化1:1关系 - teachers.user_id NOT NULL + UNIQUE
ALTER TABLE teachers
ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE teachers
ADD CONSTRAINT teachers_user_id_key UNIQUE;
```

### 9.4 冗余字段移除

```sql
-- 从students表移除冗余字段
ALTER TABLE students DROP COLUMN IF EXISTS avatar_url;
ALTER TABLE students DROP COLUMN IF EXISTS has_avatar;
ALTER TABLE students DROP COLUMN IF EXISTS attachment_id;
ALTER TABLE students DROP COLUMN IF EXISTS is_synced;
ALTER TABLE students DROP COLUMN IF EXISTS name;

-- 从courses表移除冗余字段
ALTER TABLE courses DROP COLUMN IF EXISTS has_avatar;
```

### 9.5 软删除简化

```sql
-- 移除is_deleted字段（之前同时有is_deleted和deleted_at）
ALTER TABLE students DROP COLUMN IF EXISTS is_deleted;
ALTER TABLE courses DROP COLUMN IF EXISTS is_deleted;
ALTER TABLE course_enrollments DROP COLUMN IF EXISTS is_deleted;
ALTER TABLE student_groups DROP COLUMN IF EXISTS is_deleted;

-- 仅保留deleted_at字段
-- WHERE deleted_at IS NULL = 未删除
-- WHERE deleted_at IS NOT NULL = 已删除
```

### 9.6 索引优化

```sql
-- 为常见查询添加索引
CREATE INDEX idx_students_user_id ON students(user_id);
CREATE INDEX idx_students_student_group_id ON students(student_group_id);
CREATE INDEX idx_course_enrollments_course_id ON course_enrollments(course_id);
CREATE INDEX idx_course_enrollments_student_id ON course_enrollments(student_id);
CREATE INDEX idx_courses_instructor_id ON courses(instructor_id);
CREATE INDEX idx_student_groups_advisor_id ON student_groups(advisor_id);
```

---

## 10. 数据关系图

### 10.1 实体关系图 (ER Diagram)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USERS                                          │
│  (中央认证表 - 单一真实来源: avatar_url, full_name)                          │
│  ┌─────────────┬──────────────┬──────────────┬─────────────┐                │
│  │ id (PK)     │ email        │ full_name    │ avatar_url  │                │
│  │ UUID        │ VARCHAR      │ VARCHAR      │ VARCHAR     │                │
│  └─────────────┴──────────────┴──────────────┴─────────────┘                │
│                          │                                                   │
│         ┌────────────────┴────────────────┐                                 │
│         │ (1:1)                    (1:1)   │                                 │
│         ▼                                 ▼                                 │
│  ┌─────────────┐                   ┌─────────────┐                         │
│  │  STUDENTS   │                   │  TEACHERS   │                         │
│  │ INT PK      │                   │  INT PK     │                         │
│  │ user_id     │                   │  user_id    │                         │
│  │ student_code│                  │  emp_code   │                         │
│  │ pin         │                   └──────┬──────┘                         │
│  │ sg_id (FK)  │                          │                                 │
│  └──────┬──────┘                          │                                 │
│         │                                 │                                 │
│  ┌──────┴──────┐                    ┌──────┴──────┐                         │
│  │ sg_id (FK)  │◄───────────────────│┌──────────┐ │                         │
│  ▼             │                    ││ courses  │ │                         │
│  ┌─────────────┐│                   ││ (1:N)    │ │                         │
│  │STUDENT_GROUPS│                   │└──────┬───┘ │                         │
│  │ UUID PK     ││                   │       │     │                         │
│  │ name        ││                   │       ▼     │                         │
│  │ code        ││                   │ ┌────────┐  │                         │
│  │ grade_level ││                   │ │sessions│  │                         │
│  │ advisor_id  ││                   │ └────┬───┘  │                         │
│  └─────────────┘│                   │      │     │                         │
│                  │                   │      ▼     │                         │
│                  │                   │ ┌────────┐  │                         │
│                  │                   │ │schedules│ │                         │
└──────────────────┴───────────────────┴─└────────┴──┘                         │
                                          │                                    │
         ┌────────────────────────────────┴────────────────────┐               │
         │                                              │                      │
         ▼                                              ▼                      │
┌─────────────────────┐                    ┌─────────────────────┐            │
│COURSE_ENROLLMENTS   │                    │  ATTENDANCES        │            │
│ (M:N - 学生选课)     │                    │                     │            │
│ course_id (FK)       │                    │ session_id (FK)     │            │
│ student_id (FK)      │                    │ student_id (FK)      │            │
│ enrolled_at          │                    │ status               │            │
│ UNIQUE(course,student)│                  │ check_in/out_time   │            │
└──────────┬──────────┘                    └──────────┬──────────┘            │
           │                                          │                        │
           ▼                                          ▼                        │
┌─────────────────────┐                    ┌─────────────────────┐            │
│   FACE_EMBEDDINGS   │                    │    FACE_EMBEDDINGS  │            │
│                     │                    │    (同一张表)        │            │
│ student_id (FK)     │                    │                     │            │
│ embedding_vector    │                    │ embedding_vector     │            │
│ registered_at       │                    │ registered_at        │            │
└─────────────────────┘                    └─────────────────────┘            │
```

### 10.2 数据流向图

```
                    ┌──────────────────────────────────────────────────────┐
                    │                      Flutter App                      │
                    │                                                        │
                    │  ┌──────────┐   ┌──────────┐   ┌──────────┐          │
                    │  │ Student  │   │  Person  │   │ CheckIn  │          │
                    │  │  Entity  │──►│  (Hive)  │◄──│ Out      │          │
                    │  └────┬─────┘   └──────────┘   └──────────┘          │
                    │       │                                                   │
                    │       ▼                                                   │
                    │  ┌──────────────────────────────────┐                    │
                    │  │         UserService              │                    │
                    │  │  - getStudents()                 │                    │
                    │  │  - registerStudent()             │                    │
                    │  │  - registerStudentsBatch()        │                    │
                    │  └──────────────┬───────────────────┘                    │
                    └─────────────────┼─────────────────────────────────────────┘
                                      │
                                      │ HTTP API
                                      ▼
┌─────────────────────────────────────┴───────────────────────────────────────┐
│                          Backend (FastAPI)                                   │
│                                                                               │
│  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐               │
│  │ StudentService │   │ CourseService  │   │ FaceService    │               │
│  └───────┬────────┘   └───────┬────────┘   └───────┬────────┘               │
│          │                     │                     │                       │
│  ┌───────┴────────┐   ┌───────┴────────┐   ┌───────┴────────┐               │
│  │ LegacyRouter   │   │   V1Routers     │   │   V1Routers     │               │
│  │ (Flutter兼容)  │   │   (现代REST)    │   │                 │               │
│  └───────┬────────┘   └───────┬────────┘   └───────┬────────┘               │
│          │                     │                     │                       │
│          └─────────────────────┴─────────────────────┘                       │
│                                │                                              │
│                                ▼                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                        PostgreSQL Database                             │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐               │  │
│  │  │  users   │  │ students │  │ courses  │  │  faces   │               │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘               │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## 11. Native端调整要点

### 11.1 人脸识别SDK调整

#### FaceDetector配置

```kotlin
// Android - FlutterLivenessDetectionRandomizedPlugin.kt

// 1. 识别模式变化
// HRM: Employee Recognition
// Education: Student Recognition

// 2. 人脸数据库来源变化
// HRM: employees表
// Education: students表

// 3. 识别结果处理
// HRM: EmployeeId → Education: StudentId
```

#### 识别结果映射

```kotlin
// 原: 返回Employee对象
// 新: 返回Student对象

data class RecognitionResult(
    val studentId: Int,        // 原: employeeId (UUID → Int)
    val name: String,
    val similarity: Float,
    val courseName: String?,   // 新增：当前课程
    val studentGroup: String?, // 新增：行政班级
)
```

### 11.2 本地存储调整

#### Hive数据库

```dart
// lib/data/local/hive_service.dart

// Person Box - 存储本地人员
// 旧: employeeId (UUID) → 新: studentId (int)
// 字段: jobTitle → 语义改为 className

class Person {
  int studentId;      // 原: String employeeId → int studentId
  String? pin;
  String name;
  String? className;  // 原: jobTitle → className
  DateTime updatedTime;
}
```

### 11.3 活体检测调整

```kotlin
// Android Liveness Detection

// 检测通过后的后续操作
// HRM: 查找Employee → 更新考勤
// Education: 查找Student → 更新考勤 + 可选关联Course
```

### 11.4 离线模式

```dart
// lib/data/local/local_service.dart

// 离线认证逻辑
// 原: Employee.withPin(pin) → 新: Student.withPin(pin)

// 离线考勤同步
// 原: SyncEmployeeEvent → 新: SyncStudentEvent
```

---

## 12. 迁移检查清单

### 12.1 后端检查项

- [ ] `students` 表已创建且有测试数据
- [ ] `courses` 表已创建且有测试数据
- [ ] `course_enrollments` 表已创建且有测试数据
- [ ] `student_groups` 表已创建且有测试数据
- [ ] User-Student 1:1关系正确
- [ ] User-Teacher 1:1关系正确
- [ ] 遗留API端点可访问
- [ ] V1 REST API端点可访问
- [ ] 人脸注册流程正常（Student）
- [ ] 考勤记录正确关联Student

### 12.2 Flutter检查项

- [ ] Student实体JSON解析正常
- [ ] Person实体Hive存储正常
- [ ] EmployeeBloc已重构为Student逻辑
- [ ] AddStudentDialog表单正常
- [ ] 学生列表页面正常显示
- [ ] 学生同步功能正常
- [ ] 人脸注册流程正常
- [ ] 考勤打卡流程正常

### 12.3 Native检查项

- [ ] 人脸识别SDK接入正常
- [ ] 活体检测流程正常
- [ ] 人脸数据库（Student）已导入
- [ ] 识别结果正确映射到Student
- [ ] 离线认证功能正常
- [ ] 离线数据同步正常

### 12.4 数据库检查项

- [ ] 旧表已重命名/删除
- [ ] 新表结构正确
- [ ] 索引已创建
- [ ] 外键约束正确
- [ ] 软删除字段统一（仅deleted_at）
- [ ] 冗余字段已移除

---

## 附录

### A. 关键文件路径

```
backend/
├── app/
│   ├── models/
│   │   ├── student.py          # 新增
│   │   ├── course.py           # 新增
│   │   ├── course_enrollment.py # 新增
│   │   ├── student_group.py    # 新增
│   │   └── user.py            # 修改
│   ├── routers/
│   │   ├── legacy_router.py    # 修改
│   │   └── v1.py               # 修改
│   ├── schemas/
│   │   ├── student_schema.py   # 新增
│   │   ├── course_schema.py    # 新增
│   │   ├── course_enrollment_schema.py # 新增
│   │   └── student_group_schema.py # 新增
│   └── services/
│       ├── student_service.py  # 新增
│       └── course_service.py   # 新增

lib/
├── entities/
│   ├── student.dart            # 新增
│   ├── register_student.dart   # 新增
│   ├── verify_student.dart     # 新增
│   └── person.dart            # 修改
├── data/
│   ├── models/
│   │   ├── student_request.dart # 新增
│   │   ├── batch_student_response.dart # 新增
│   │   └── user_model.dart    # 已废弃，使用Student
│   └── remote/
│       ├── api_endpoint.dart   # 修改
│       └── user_service.dart  # 修改
└── pages/
    ├── employee/
    │   ├── blocs/
    │   │   ├── student_bloc.dart # 新命名（原employee_bloc）
    │   │   └── student_state.dart # 新命名（原employee_state）
    │   ├── student_page.dart    # 新命名（原employee_page）
    │   └── add_student_dialog.dart # 新增
    ├── register_face/
    │   └── register_face_page.dart # 已调整
    └── checking/
        └── widgets/
            └── check_in_widget.dart # 已调整
```

### A.2 第三轮更新 - Employee → Student 重命名

| 文件路径 (旧) | 文件路径 (新) | 变更内容 |
|--------------|--------------|----------|
| `lib/pages/employee/blocs/employee_bloc.dart` | `lib/pages/employee/blocs/student_bloc.dart` | 已删除重建 |
| `lib/pages/employee/blocs/employee_state.dart` | `lib/pages/employee/blocs/student_state.dart` | 已删除重建 |
| `lib/pages/employee/employee_page.dart` | `lib/pages/employee/student_page.dart` | 已重命名 |
| `lib/entities/user.dart` | - | 标记为废弃 |
| `lib/data/models/user_model.dart` | - | 标记为废弃 |
| `lib/di/injection.config.dart` | - | 更新import和引用 |

### A.3 类名重命名

| 旧类名 | 新类名 | 文件 |
|--------|--------|------|
| `EmployeeBloc` | `StudentBloc` | `blocs/student_bloc.dart` |
| `EmployeeState` | `StudentState` | `blocs/student_state.dart` |
| `EmployeePage` | `StudentPage` | `student_page.dart` |

### B. 术语对照表

| 英文 | 越南文 (UI) | 中文 | HRM术语 | Education术语 |
|------|-------------|------|---------|---------------|
| Student | Học Sinh | 学生 | Employee | Student |
| Teacher | Giáo Viên | 教师 | - | Teacher |
| Course | Khóa Học | 课程/教学班 | Classroom | Course |
| Student Group | Lớp Học | 行政班级 | Department/Class | Student Group |
| Attendance | Điểm Danh | 考勤 | Attendance | Attendance |
| PIN Code | Mã PIN | PIN码 | PIN Code | PIN Code |
| Check In | Check In | 签到 | Check In | Check In |
| Check Out | Check Out | 签退 | Check Out | Check Out |

### C. 版本信息

- **Flutter**: 3.x
- **Dart**: 3.x
- **FastAPI**: 0.109+
- **SQLAlchemy**: 2.0+
- **PostgreSQL**: 15+
- **Hive**: 2.x

---

## 13. 第二轮更新 - 额外文件调整

### 13.1 新增已修改文件列表

以下文件在第一轮报告后进行了额外调整：

| 文件路径 | 变更内容 |
|----------|----------|
| `lib/route/app_route.dart` | 路由名称从 `employees` → `students` |
| `lib/data/models/user_model.dart` | 标记为 `@Deprecated`，推荐使用 Student |
| `lib/entities/user.dart` | 标记为 `@Deprecated`，推荐使用 Student |
| `lib/pages/checking/bloc/checking_bloc.dart` | 移除旧的 Employee 相关注释 |
| `lib/pages/employee/employee_page.dart` | 方法重命名 |
| `lib/pages/register_face/register_face_page.dart` | 移除 Employee 注释 |
| `lib/pages/setting/setting_page.dart` | 使用新路由名称 |
| `lib/route/load_multi_images.dart` | 标记为废弃，更新注释 |
| `backend/app/models/teacher.py` | `department` → `subject` |
| `ios/Runner/Info.plist` | 更新iOS权限描述文字 |

### 13.2 详细变更说明

#### lib/route/app_route.dart

```dart
class RouterName {
  // Education: Students
  static const String students = '/students';

  // Legacy route names for backward compatibility
  @Deprecated('Use students instead')
  static const String employees = '/students';
}
```

#### lib/data/models/user_model.dart

```dart
// ============================================================
// DEPRECATED: Use Student entity instead
// This file is kept for backward compatibility with legacy code
// ============================================================

import '../../../entities/student.dart';

/// @deprecated Use `Student` entity from `lib/entities/student.dart` instead.
/// This model was used for HRM system (Employee management).
/// Now migrated to Education system (Student management).
@Deprecated('Use Student entity instead')
class UserModel extends Student {
  UserModel.fromJson(Map<String, dynamic> json) : super.fromJson(json);
}
```

#### lib/entities/user.dart

```dart
// ============================================================
// DEPRECATED: User entity is replaced by Student entity
// This file is kept for backward compatibility only
// ============================================================

/// @deprecated Use `Student` entity from `lib/entities/student.dart` instead.
/// This class was used for HRM system (Employee management).
/// Now migrated to Education system (Student management).
@Deprecated('Use Student entity instead')
class User {
  int? id;
  String? barcode;
  String? name;
  String? employeeCode;  // Renamed to: studentCode
  String? jobTitle;  // Renamed to: className (for students)
  // ...
}
```

#### lib/pages/employee/employee_page.dart

```dart
// 方法重命名
// _syncLocalEmployeesToServer() → _syncLocalStudentsToServer()
// _confirmAndSyncEmployees() → _confirmAndSyncStudents()
```

#### backend/app/models/teacher.py

```python
class Teacher(Base):
    """Teacher profile — strict 1:1 with User (role='teacher').

    Stores teacher-specific business data such as employee code and subject.
    Avatar is stored in User model (single source of truth).
    """
    # Education: department → subject (môn học/ chuyên môn)
    subject: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
```

---

## 14. Native端额外调整要点

### 14.1 教师模型调整

```kotlin
// Android/iOS - Teacher data model
data class Teacher(
    val id: Int,
    val userId: String,
    val employeeCode: String?,  // 教师工号 (Mã số giáo viên)
    val subject: String?,        // 任教科目 (Môn dạy)
    val phone: String?,
    // department 字段已移除 → 使用 subject
)
```

### 14.2 数据库列重命名

```sql
-- teachers表
ALTER TABLE teachers RENAME COLUMN department TO subject;
```

### 14.3 课程安排调整

```kotlin
// Course schedule - Education system
data class Course(
    val id: String,
    val name: String,
    val courseCode: String?,    // 课程代码
    val instructorId: Int,      // 教师ID
    val subject: String?,        // 科目
    val gradeLevel: Int?,      // 年级
    val academicYear: String?, // 学年
)
```

---

*报告更新完毕 - 2026-03-20*
