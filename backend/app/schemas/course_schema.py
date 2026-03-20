from __future__ import annotations
from typing import Optional
"""Course schemas — create and read responses for the /courses endpoints."""
import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class CourseCreate(BaseModel):
    """POST /courses — create a new course."""

    course_name: str = Field(..., min_length=1, max_length=255, examples=["12A1"])
    subject: Optional[str] = Field(None, max_length=255, examples=["Toán"])
    course_code: Optional[str] = Field(None, max_length=50, examples=["MATH101"])


class CourseOut(BaseModel):
    """Read response for a single course."""

    id: uuid.UUID
    course_name: str
    subject: Optional[str]
    course_code: Optional[str]
    instructor_id: Optional[uuid.UUID]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class CourseList(BaseModel):
    """Paginated wrapper for GET /courses."""

    total: int
    items: list[CourseOut]
