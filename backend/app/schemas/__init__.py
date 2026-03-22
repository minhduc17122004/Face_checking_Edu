from __future__ import annotations
# app/schemas/__init__.py
# Re-export all Pydantic schemas so routers can import from `app.schemas` directly.

from app.schemas.auth_schema import (  # noqa: F401
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UserInfo,
    AvatarUploadResponse,
)
from app.schemas.user_schema import UserOut, UserList  # noqa: F401
from app.schemas.student_schema import (  # noqa: F401
    StudentCreate,
    StudentOut,
    StudentList,
    StudentOutLegacy,
    StudentCreateLegacy,
    BatchCreateRequest,
    BatchCreateResponse,
    GetAllStudentsResponse,
    AvatarUploadFile,
    AvatarUploadResponse,
)
from app.schemas.course_schema import CourseCreate, CourseOut, CourseList  # noqa: F401
from app.schemas.attendance_schema import (  # noqa: F401
    CheckinRequest,
    AttendanceOut,
    AttendanceList,
    BulkSyncEntry,
    BulkSyncRequest,
    BulkSyncResponse,
    BulkSyncItemResult,
)
from app.schemas.face_schema import (  # noqa: F401
    FaceRegisterRequest,
    FaceEmbeddingOut,
    FaceEmbeddingList,
    FaceDataOut,
)
from app.schemas.time_slot_schema import (  # noqa: F401
    TimeSlotCreate,
    TimeSlotOut,
    TimeSlotList,
)
from app.schemas.course_enrollment_schema import (  # noqa: F401
    CourseEnrollmentCreate,
    CourseEnrollmentOut,
    CourseEnrollmentList,
)
from app.schemas.schedule_schema import (  # noqa: F401
    ScheduleCreate,
    ScheduleOut,
    ScheduleWithTimeSlot,
    ScheduleList,
)
from app.schemas.session_schema import (  # noqa: F401
    SessionCreate,
    SessionUpdate,
    SessionOut,
    SessionWithSchedule,
    SessionList,
    SessionSummary,
)
from app.schemas.attendance_new_schema import (  # noqa: F401
    AttendanceCreate,
    AttendanceOut,
    AttendanceWithDetails,
    AttendanceList,
    AttendanceSummary,
)
from app.schemas.student_group_schema import (  # noqa: F401
    StudentGroupCreate,
    StudentGroupUpdate,
    StudentGroupOut,
    StudentGroupList,
)
from app.schemas.v1.department import (  # noqa: F401
    DepartmentCreate,
    DepartmentUpdate,
    DepartmentOut,
    DepartmentWithStats,
    DepartmentList,
)
from app.schemas.v1.teacher import (  # noqa: F401
    TeacherOut,
    TeacherAssignDepartment,
    TeacherList,
)
from app.schemas.v1.attendance import (  # noqa: F401
    CheckinRequest,
    CheckinResponse,
)
