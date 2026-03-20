from __future__ import annotations
"""Student schemas — Flutter-compatible student shapes + REST shapes.

Flutter legacy API uses the term "student" / "Student" for the person entity.
The schemas in this file are designed to satisfy BOTH the modern REST API and
the legacy Flutter API response contract:

    GET /api/student/get_all_students
    → { "data": { "students": [<StudentOutLegacy>, ...] } }
"""
import uuid
from datetime import datetime
from typing import Optional, Any

from pydantic import BaseModel, Field


# ──────────────────────────────────────────────────────────────
# REST API schemas
# ──────────────────────────────────────────────────────────────
class StudentCreate(BaseModel):
    """POST /students — create a single student (modern REST)."""

    user_id: Optional[uuid.UUID] = Field(None)
    student_code: Optional[str] = Field(None, max_length=50, examples=["221121521101"])
    pin: Optional[str] = Field(None, max_length=10, examples=["1234"])
    student_group_id: Optional[uuid.UUID] = Field(None)


class StudentOut(BaseModel):
    """Read response for a single student (modern REST)."""

    id: int
    user_id: Optional[uuid.UUID]
    student_code: Optional[str]
    pin: Optional[str]
    student_group_id: Optional[uuid.UUID]
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
class StudentCreateLegacy(BaseModel):
    """POST /api/student/create — Flutter multipart-equivalent body.

    The Flutter app sends these fields as multipart form data.
    We handle file separately via UploadFile; only JSON fields here.
    """

    name: str = Field(..., examples=["Trần Thị B"])
    pin: Optional[str] = Field(None, examples=["1234"])
    jobTitle: Optional[str] = Field(None, examples=["12A1"])   # camelCase from Flutter


class StudentOutLegacy(BaseModel):
    """Single student record in the Flutter legacy response format.

    Maps to Flutter's `Student.fromJson()`:
        id        → int
        name      → String (from users.full_name)
        pin       → String?
        jobTitle  → String?    (used as class code)
        hasAvatar → bool (derived from users.avatar_url)
        attachmentId → String?
        avatarUrl → String? (from users.avatar_url)
    """

    id: int
    name: str
    pin: Optional[str] = None
    jobTitle: Optional[str] = None       # Flutter camelCase
    hasAvatar: bool = False
    attachmentId: Optional[str] = None
    avatarUrl: Optional[str] = None

    model_config = {"from_attributes": True, "populate_by_name": True}

    @classmethod
    def from_student(cls, s: Any) -> "StudentOutLegacy":
        """Convert a Student ORM instance to Flutter-compatible StudentOutLegacy."""
        return cls(
            id=s.id,
            name=s.name if hasattr(s, 'name') else (s.user.full_name if s.user else ""),
            pin=s.pin,
            jobTitle=getattr(s, 'student_code', None),
            hasAvatar=s.has_avatar if hasattr(s, 'has_avatar') else bool(s.user.avatar_url if s.user else None),
            attachmentId=None,
            avatarUrl=s.user.avatar_url if s.user else None,
        )


class BatchCreateRequest(BaseModel):
    """POST /api/student/create/batch — array of students."""

    students: list[StudentCreateLegacy]


class BatchCreateResponse(BaseModel):
    """Response for batch student creation."""

    created: int
    failed: int
    students: list[StudentOutLegacy]


class GetAllStudentsResponse(BaseModel):
    """GET /api/student/get_all_students Flutter response envelope."""

    class _Data(BaseModel):
        students: list[StudentOutLegacy]

    data: _Data

    @classmethod
    def build(cls, students: list[StudentOutLegacy]) -> "GetAllStudentsResponse":
        return cls(data=cls._Data(students=students))


class AvatarUploadFile(BaseModel):
    """Single uploaded avatar file descriptor inside the upload response."""

    studentId: int
    fileName: str
    url: str


class AvatarUploadResponse(BaseModel):
    """POST /api/student/avatars/upload Flutter response envelope."""

    class _Data(BaseModel):
        uploadId: str
        files: list[AvatarUploadFile]

    data: _Data
