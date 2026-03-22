from __future__ import annotations
from datetime import datetime
import uuid
from typing import Literal, Optional
from pydantic import BaseModel, Field


class CourseCreate(BaseModel):
    """POST /api/v1/courses — create a new course."""

    course_name: str = Field(min_length=1, max_length=255)
    subject: Optional[str] = None
    course_code: Optional[str] = Field(None, max_length=50)
    department_id: Optional[uuid.UUID] = None
    room_id: Optional[uuid.UUID] = None
    attendance_mode: Literal["preset", "flexible", "custom"] = "preset"
    attendance_before_minutes: int = Field(default=30, ge=0, le=120)
    attendance_after_minutes: int = Field(default=30, ge=0, le=120)


class CourseUpdate(BaseModel):
    """PUT /api/v1/courses/{id} — update an existing course."""

    course_name: Optional[str] = Field(None, min_length=1, max_length=255)
    subject: Optional[str] = None
    course_code: Optional[str] = Field(None, max_length=50)
    department_id: Optional[uuid.UUID] = None
    room_id: Optional[uuid.UUID] = None
    attendance_mode: Optional[Literal["preset", "flexible", "custom"]] = None
    attendance_before_minutes: Optional[int] = Field(None, ge=0, le=120)
    attendance_after_minutes: Optional[int] = Field(None, ge=0, le=120)


class CourseOut(BaseModel):
    """Read response for a single course."""

    id: uuid.UUID
    course_name: str
    subject: Optional[str] = None
    course_code: Optional[str] = None
    instructor_id: uuid.UUID | None = None
    department_id: uuid.UUID | None = None
    room_id: uuid.UUID | None = None
    attendance_mode: Literal["preset", "flexible", "custom"] = "preset"
    attendance_before_minutes: int = 30
    attendance_after_minutes: int = 30
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None
    instructor_name: Optional[str] = None
    department_name: Optional[str] = None
    room_name: Optional[str] = None
    enrolled_count: int = 0

    model_config = {"from_attributes": True}


class CourseList(BaseModel):
    """Paginated wrapper for GET /api/v1/courses."""

    total: int
    items: list[CourseOut]


class CourseStudentDetail(BaseModel):
    """Single student with face status in a course."""

    student_id: int
    user_id: Optional[str] = None
    pin: Optional[str] = None
    has_face: bool
    embedding_count: int
    enrolled_at: datetime

    model_config = {"from_attributes": True}


class CourseStudentListResponse(BaseModel):
    """GET /api/v1/courses/{id}/students — student list with face status."""

    course_id: uuid.UUID
    total: int
    students: list[CourseStudentDetail]
