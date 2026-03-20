from __future__ import annotations
from datetime import datetime
import uuid
from typing import Optional
from pydantic import BaseModel


class CourseEnrollmentCreate(BaseModel):
    """POST /api/v1/course-enrollments — create enrollment."""

    course_id: uuid.UUID
    student_id: int


class CourseEnrollmentOut(BaseModel):
    """Read response for a course enrollment."""

    id: uuid.UUID
    course_id: uuid.UUID
    student_id: int
    enrolled_at: datetime

    model_config = {"from_attributes": True}


class CourseEnrollmentList(BaseModel):
    """Paginated wrapper for GET /api/v1/course-enrollments."""

    total: int
    items: list[CourseEnrollmentOut]
