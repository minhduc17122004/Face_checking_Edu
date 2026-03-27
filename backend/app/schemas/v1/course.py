from __future__ import annotations
from datetime import datetime
import uuid
from typing import Literal, Optional
from pydantic import BaseModel, Field


class CourseCreate(BaseModel):
    """POST /api/v1/courses — create a new course."""

    course_name: str = Field(min_length=1, max_length=255)
    course_code: Optional[str] = Field(None, max_length=50)
    department_id: Optional[uuid.UUID] = None
    room_id: Optional[uuid.UUID] = None
    teacher_id: Optional[int] = Field(None, description="Teacher ID from teachers table to assign as instructor")
    attendance_mode: Literal["preset", "flexible", "custom"] = "preset"
    custom_window_start_minutes: int = Field(default=0, ge=0, le=120)
    custom_window_end_minutes: int = Field(default=30, ge=0, le=240)
    day_of_week: Optional[int] = Field(None, ge=1, le=7, description="Day of week (1=Mon, 7=Sun)")
    time_slot_id: Optional[int] = Field(None, description="Time slot ID to create a schedule entry")


class CourseUpdate(BaseModel):
    """PUT /api/v1/courses/{id} — update an existing course."""

    course_name: Optional[str] = Field(None, min_length=1, max_length=255)
    course_code: Optional[str] = Field(None, max_length=50)
    department_id: Optional[uuid.UUID] = None
    room_id: Optional[uuid.UUID] = None
    teacher_id: Optional[int] = Field(None, description="Teacher ID from teachers table to reassign instructor")
    attendance_mode: Optional[Literal["preset", "flexible", "custom"]] = None
    custom_window_start_minutes: Optional[int] = Field(None, ge=0, le=120)
    custom_window_end_minutes: Optional[int] = Field(None, ge=0, le=240)
    day_of_week: Optional[int] = Field(None, ge=1, le=7)
    time_slot_id: Optional[int] = Field(None)


class CourseOut(BaseModel):
    """Read response for a single course."""

    id: uuid.UUID
    course_name: str
    course_code: Optional[str] = None
    teacher_id: int | None = None
    department_id: uuid.UUID | None = None
    room_id: uuid.UUID | None = None
    attendance_mode: Literal["preset", "flexible", "custom"] = "preset"
    custom_window_start_minutes: int = 0
    custom_window_end_minutes: int = 30
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None
    teacher_name: Optional[str] = None
    department_name: Optional[str] = None
    room_name: Optional[str] = None
    enrolled_count: int = 0
    day_of_week: Optional[int] = None
    time_slot_id: Optional[int] = None
    time_slot_name: Optional[str] = None

    model_config = {"from_attributes": True}


class CourseList(BaseModel):
    """Paginated wrapper for GET /api/v1/courses."""

    total: int
    items: list[CourseOut]


class CourseStudentDetail(BaseModel):
    """Single student with face status in a course."""

    student_id: int
    student_code: Optional[str] = None
    name: Optional[str] = None
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


class BatchEnrollRequest(BaseModel):
    """POST /api/v1/courses/{id}/students/batch — enroll multiple students."""

    student_ids: list[int] = Field(min_length=1, max_length=100)


class BatchEnrollResult(BaseModel):
    """Result for each student in batch enrollment."""

    student_id: int
    success: bool
    message: str


class BatchEnrollResponse(BaseModel):
    """Batch enrollment response."""

    course_id: uuid.UUID
    total_requested: int
    total_enrolled: int
    total_already_enrolled: int
    results: list[BatchEnrollResult]


class AvailableStudentDetail(BaseModel):
    """Student available for enrollment with face status."""

    id: int
    user_id: Optional[str] = None
    student_code: Optional[str] = None
    pin: Optional[str] = None
    full_name: Optional[str] = None
    has_face: bool
    embedding_count: int

    model_config = {"from_attributes": True}


class AvailableStudentListResponse(BaseModel):
    """GET /api/v1/courses/{id}/available-students — students not enrolled in course."""

    course_id: uuid.UUID
    total: int
    students: list[AvailableStudentDetail]
