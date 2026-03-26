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
    ScheduleUpdate,
    ScheduleOut,
    ScheduleWithTimeSlot,
    ScheduleList,
    ScheduleListWithTimeSlot,
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
from app.schemas.v1.room import (
    RoomCreate,
    RoomUpdate,
    RoomOut,
    RoomList,
    AssignRoomRequest,
)
from app.schemas.v1.device_request import (
    DeviceRequestCreate,
    DeviceRequestSubmit,
    ApproveRequest,
    RejectRequest,
    DeviceRequestResponse,
    DeviceRequestList,
)
from app.schemas.v1.attendance_config import (
    AttendanceConfigCreate,
    AttendanceConfigUpdate,
    AttendanceConfigResponse,
)
from app.schemas.v1.room_session import (
    RoomSessionResponse,
    RoomSessionList,
)
from app.schemas.v1.attendance_checkin import (
    ManualCheckinRequest,
    ManualCheckinResponse,
    AttendanceRecordResponse,
    AttendanceCheckinList,
    AttendanceSummaryResponse,
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
    "ScheduleUpdate",
    "ScheduleOut",
    "ScheduleWithTimeSlot",
    "ScheduleList",
    "ScheduleListWithTimeSlot",
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
    # Room
    "RoomCreate",
    "RoomUpdate",
    "RoomOut",
    "RoomList",
    "AssignRoomRequest",
    # DeviceRequest (Phase 9)
    "DeviceRequestCreate",
    "DeviceRequestSubmit",
    "ApproveRequest",
    "RejectRequest",
    "DeviceRequestResponse",
    "DeviceRequestList",
    # AttendanceConfig (Phase 9)
    "AttendanceConfigCreate",
    "AttendanceConfigUpdate",
    "AttendanceConfigResponse",
    # RoomSession (Phase 9)
    "RoomSessionResponse",
    "RoomSessionList",
    # AttendanceCheckin (Phase 9)
    "ManualCheckinRequest",
    "ManualCheckinResponse",
    "AttendanceRecordResponse",
    "AttendanceCheckinList",
    "AttendanceSummaryResponse",
]
