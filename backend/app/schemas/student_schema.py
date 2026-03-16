"""Student schemas — Flutter-compatible employee shapes + REST shapes.

Flutter legacy API uses the term "employee" / "Employee" for what this
system calls a "student".  The schemas in this file are designed to satisfy
BOTH the modern REST API and the legacy Flutter API response contract:

    GET /api/employee/get_all_employees
    → { "data": { "employees": [<EmployeeOut>, ...] } }
"""
import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


# ──────────────────────────────────────────────────────────────
# REST API schemas
# ──────────────────────────────────────────────────────────────
class StudentCreate(BaseModel):
    """POST /students — create a single student (modern REST)."""

    name: str = Field(..., min_length=1, max_length=255, examples=["Trần Thị B"])
    pin: str | None = Field(None, max_length=10, examples=["1234"])
    job_title: str | None = Field(None, max_length=100, examples=["12A1"])
    has_avatar: bool = Field(False)
    attachment_id: str | None = Field(None, max_length=255)


class StudentOut(BaseModel):
    """Read response for a single student (modern REST)."""

    id: int
    user_id: uuid.UUID | None
    name: str
    pin: str | None
    job_title: str | None
    avatar_url: str | None
    has_avatar: bool
    attachment_id: str | None
    is_synced: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class StudentList(BaseModel):
    """Paginated wrapper for GET /students."""

    total: int
    items: list[StudentOut]


# ──────────────────────────────────────────────────────────────
# Flutter legacy API schemas
# These mirror the exact JSON shapes the Flutter app sends / expects.
# ──────────────────────────────────────────────────────────────
class EmployeeCreateLegacy(BaseModel):
    """POST /api/employee/create — Flutter multipart-equivalent body.

    The Flutter app sends these fields as multipart form data.
    We handle file separately via UploadFile; only JSON fields here.
    """

    name: str = Field(..., examples=["Trần Thị B"])
    pin: str | None = Field(None, examples=["1234"])
    jobTitle: str | None = Field(None, examples=["12A1"])   # camelCase from Flutter
    hasAvatar: bool = Field(False)
    attachmentId: str | None = Field(None)


class EmployeeOut(BaseModel):
    """Single employee record in the Flutter legacy response format.

    Maps to Flutter's `Employee.fromJson()`:
        id        → int
        name      → String
        pin       → String?
        jobTitle  → String?    (used as class code)
        hasAvatar → bool
        attachmentId → String?
    """

    id: int
    name: str
    pin: str | None = None
    jobTitle: str | None = None       # Flutter camelCase
    hasAvatar: bool = False
    attachmentId: str | None = None
    avatarUrl: str | None = None

    model_config = {"from_attributes": True, "populate_by_name": True}

    @classmethod
    def from_student(cls, s: Any) -> "EmployeeOut":
        """Convert a Student ORM instance to Flutter-compatible EmployeeOut."""
        return cls(
            id=s.id,
            name=s.name,
            pin=s.pin,
            jobTitle=s.job_title,
            hasAvatar=s.has_avatar,
            attachmentId=s.attachment_id,
            avatarUrl=s.avatar_url,
        )


class BatchCreateRequest(BaseModel):
    """POST /api/employee/create/batch — array of employees."""

    employees: list[EmployeeCreateLegacy]


class BatchCreateResponse(BaseModel):
    """Response for batch employee creation."""

    created: int
    failed: int
    employees: list[EmployeeOut]


class GetAllEmployeesResponse(BaseModel):
    """GET /api/employee/get_all_employees Flutter response envelope."""

    class _Data(BaseModel):
        employees: list[EmployeeOut]

    data: _Data

    @classmethod
    def build(cls, employees: list[EmployeeOut]) -> "GetAllEmployeesResponse":
        return cls(data=cls._Data(employees=employees))


class AvatarUploadFile(BaseModel):
    """Single uploaded avatar file descriptor inside the upload response."""

    empId: int
    fileName: str
    url: str


class AvatarUploadResponse(BaseModel):
    """POST /api/employee/avatars/upload Flutter response envelope."""

    class _Data(BaseModel):
        uploadId: str
        files: list[AvatarUploadFile]

    data: _Data
