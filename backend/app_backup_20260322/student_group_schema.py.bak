from __future__ import annotations
from typing import Optional
from datetime import datetime

import uuid
from pydantic import BaseModel, Field


class StudentGroupCreate(BaseModel):
    """POST /student-groups — create a new student group."""

    code: str = Field(..., min_length=1, max_length=50, examples=["48K21.1"])
    name: Optional[str] = Field(None, max_length=255, examples=["Lớp CNTT K21.1"])
    faculty: Optional[str] = Field(None, max_length=255, examples=["Khoa Công Nghệ Thông Tin"])
    course_year: Optional[str] = Field(None, max_length=10, examples=["K21"])
    advisor_id: Optional[uuid.UUID] = Field(None, examples=["550e8400-e29b-41d4-a716-446655440000"])


class StudentGroupUpdate(BaseModel):
    """PATCH /student-groups/{id} — update a student group."""

    code: Optional[str] = Field(None, min_length=1, max_length=50)
    name: Optional[str] = Field(None, max_length=255)
    faculty: Optional[str] = Field(None, max_length=255)
    course_year: Optional[str] = Field(None, max_length=10)
    advisor_id: Optional[uuid.UUID] = None


class StudentGroupOut(BaseModel):
    """Read response for a single student group."""

    id: uuid.UUID
    code: str
    name: Optional[str]
    faculty: Optional[str]
    course_year: Optional[str]
    advisor_id: Optional[uuid.UUID]
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class StudentGroupList(BaseModel):
    """Paginated wrapper for GET /student-groups."""

    total: int
    items: list[StudentGroupOut]
