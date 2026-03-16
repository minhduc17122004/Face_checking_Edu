# app/schemas/__init__.py
# Re-export all Pydantic schemas so routers can import from `app.schemas` directly.

from app.schemas.auth_schema import (  # noqa: F401
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UserInfo,
)
from app.schemas.user_schema import UserOut, UserList  # noqa: F401
from app.schemas.student_schema import (  # noqa: F401
    StudentCreate,
    StudentOut,
    StudentList,
    EmployeeOut,
    EmployeeCreateLegacy,
    BatchCreateRequest,
    BatchCreateResponse,
    GetAllEmployeesResponse,
    AvatarUploadFile,
    AvatarUploadResponse,
)
from app.schemas.classroom_schema import ClassCreate, ClassOut, ClassList  # noqa: F401
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
