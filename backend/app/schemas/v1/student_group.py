from __future__ import annotations
from datetime import datetime
import uuid
from typing import Optional
from pydantic import BaseModel, Field


class StudentGroupCreate(BaseModel):
    """POST /api/v1/student-groups — create a new student group."""

    code: str = Field(min_length=1, max_length=50)
    name: Optional[str] = None
    faculty: Optional[str] = None
    course_year: Optional[str] = None
    advisor_id: Optional[uuid.UUID] = None


class StudentGroupUpdate(BaseModel):
    """PATCH /api/v1/student-groups/{id} — update a student group."""

    code: Optional[str] = Field(None, min_length=1, max_length=50)
    name: Optional[str] = None
    faculty: Optional[str] = None
    course_year: Optional[str] = None
    advisor_id: Optional[uuid.UUID] = None


class StudentGroupOut(BaseModel):
    """Read response for a single student group."""

    id: uuid.UUID
    code: str
    name: Optional[str] = None
    faculty: Optional[str] = None
    course_year: Optional[str] = None
    advisor_id: Optional[uuid.UUID] = None
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class StudentGroupList(BaseModel):
    """Paginated wrapper for GET /api/v1/student-groups."""

    total: int
    items: list[StudentGroupOut]
