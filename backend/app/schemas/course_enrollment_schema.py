from __future__ import annotations
from typing import Optional

import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class CourseEnrollmentCreate(BaseModel):
    """POST /course-enrollments — enroll a student in a course."""

    course_id: uuid.UUID = Field(..., examples=["550e8400-e29b-41d4-a716-446655440000"])
    student_id: int = Field(..., examples=[1])


class CourseEnrollmentOut(BaseModel):
    """Read response for a course enrollment."""

    id: uuid.UUID
    course_id: uuid.UUID
    student_id: int
    enrolled_at: datetime

    model_config = {"from_attributes": True}


class CourseEnrollmentList(BaseModel):
    """Paginated wrapper for GET /course-enrollments."""

    total: int
    items: list[CourseEnrollmentOut]
