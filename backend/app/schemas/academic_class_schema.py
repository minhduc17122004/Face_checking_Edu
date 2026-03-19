from __future__ import annotations
from typing import Optional
from datetime import datetime

import uuid
from pydantic import BaseModel, Field


class AcademicClassCreate(BaseModel):
    """POST /academic-classes — create a new academic class."""

    code: str = Field(..., min_length=1, max_length=50, examples=["48K21.1"])
    name: Optional[str] = Field(None, max_length=255, examples=["Lớp CNTT K21.1"])
    faculty: Optional[str] = Field(None, max_length=255, examples=["Khoa Công Nghệ Thông Tin"])
    course_year: Optional[str] = Field(None, max_length=10, examples=["K21"])
    advisor_id: Optional[uuid.UUID] = Field(None, examples=["550e8400-e29b-41d4-a716-446655440000"])


class AcademicClassUpdate(BaseModel):
    """PATCH /academic-classes/{id} — update an academic class."""

    code: Optional[str] = Field(None, min_length=1, max_length=50)
    name: Optional[str] = Field(None, max_length=255)
    faculty: Optional[str] = Field(None, max_length=255)
    course_year: Optional[str] = Field(None, max_length=10)
    advisor_id: Optional[uuid.UUID] = None


class AcademicClassOut(BaseModel):
    """Read response for a single academic class."""

    id: uuid.UUID
    code: str
    name: Optional[str]
    faculty: Optional[str]
    course_year: Optional[str]
    advisor_id: Optional[uuid.UUID]
    created_at: datetime
    updated_at: datetime
    is_deleted: bool

    model_config = {"from_attributes": True}


class AcademicClassList(BaseModel):
    """Paginated wrapper for GET /academic-classes."""

    total: int
    items: list[AcademicClassOut]
