from __future__ import annotations
# app/schemas/v1/__init__.py
# Re-exports all v1 API schemas.

from app.schemas.v1.auth import (
    LoginRequest,
    RegisterRequest,
    RefreshRequest,
    UserInfo,
    TokenResponse,
    MessageResponse,
    AvatarUploadResponse,
)
from app.schemas.v1.attendance import (
    AttendanceCreate,
    AttendanceOut,
    AttendanceWithDetails,
    AttendanceList,
    AttendanceSummary,
)
from app.schemas.v1.session import (
    SessionCreate,
    SessionUpdate,
    SessionOut,
    SessionWithSchedule,
    SessionList,
)
from app.schemas.v1.student import (
    StudentCreate,
    StudentOut,
    StudentList,
)
from app.schemas.v1.course import (
    CourseCreate,
    CourseOut,
    CourseList,
    CourseStudentDetail,
    CourseStudentListResponse,
)
from app.schemas.v1.device import (
    DeviceCreate,
    DeviceUpdate,
    DeviceResponse,
)
from app.schemas.v1.user import (
    UserOut,
    UserList,
)
from app.schemas.v1.schedule import (
    ScheduleCreate,
    ScheduleOut,
    ScheduleWithTimeSlot,
    ScheduleList,
)
from app.schemas.v1.time_slot import (
    TimeSlotCreate,
    TimeSlotOut,
    TimeSlotList,
)
from app.schemas.v1.course_enrollment import (
    CourseEnrollmentCreate,
    CourseEnrollmentOut,
    CourseEnrollmentList,
)
from app.schemas.v1.student_group import (
    StudentGroupCreate,
    StudentGroupUpdate,
    StudentGroupOut,
    StudentGroupList,
)
from app.schemas.v1.common import PaginationParams, PaginatedResponse, ErrorDetail
from app.schemas.v1.face import (
    FaceRegisterRequest,
    FaceStatusResponse,
    FaceBulkExport,
    FaceExportItem,
    BulkAttendanceRequest,
    BulkAttendanceItem,
    BulkAttendanceResponse,
    BulkResultItem,
)

__all__ = [
    # Auth
    "LoginRequest",
    "RegisterRequest",
    "RefreshRequest",
    "UserInfo",
    "TokenResponse",
    "MessageResponse",
    "AvatarUploadResponse",
    # Attendance
    "AttendanceCreate",
    "AttendanceOut",
    "AttendanceWithDetails",
    "AttendanceList",
    "AttendanceSummary",
    # Session
    "SessionCreate",
    "SessionUpdate",
    "SessionOut",
    "SessionWithSchedule",
    "SessionList",
    # Student
    "StudentCreate",
    "StudentOut",
    "StudentList",
    # Course
    "CourseCreate",
    "CourseOut",
    "CourseList",
    "CourseStudentDetail",
    "CourseStudentListResponse",
    # Device
    "DeviceCreate",
    "DeviceUpdate",
    "DeviceResponse",
    # User
    "UserOut",
    "UserList",
    # Schedule
    "ScheduleCreate",
    "ScheduleOut",
    "ScheduleWithTimeSlot",
    "ScheduleList",
    # TimeSlot
    "TimeSlotCreate",
    "TimeSlotOut",
    "TimeSlotList",
    # CourseEnrollment
    "CourseEnrollmentCreate",
    "CourseEnrollmentOut",
    "CourseEnrollmentList",
    # StudentGroup
    "StudentGroupCreate",
    "StudentGroupUpdate",
    "StudentGroupOut",
    "StudentGroupList",
    # Common
    "PaginationParams",
    "PaginatedResponse",
    "ErrorDetail",
    # Face
    "FaceRegisterRequest",
    "FaceStatusResponse",
    "FaceBulkExport",
    "FaceExportItem",
    "BulkAttendanceRequest",
    "BulkAttendanceItem",
    "BulkAttendanceResponse",
    "BulkResultItem",
]
