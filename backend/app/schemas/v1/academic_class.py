from __future__ import annotations
from datetime import datetime
import uuid
from pydantic import BaseModel, Field


class AcademicClassCreate(BaseModel):
    code: str = Field(min_length=1, max_length=50)
    name: str | None = None
    faculty: str | None = None
    course_year: str | None = None
    advisor_id: uuid.UUID | None = None


class AcademicClassUpdate(BaseModel):
    code: str | None = None
    name: str | None = None
    faculty: str | None = None
    course_year: str | None = None
    advisor_id: uuid.UUID | None = None


class AcademicClassOut(BaseModel):
    id: uuid.UUID
    code: str
    name: str | None = None
    faculty: str | None = None
    course_year: str | None = None
    advisor_id: uuid.UUID | None = None
    created_at: datetime
    updated_at: datetime
    is_deleted: bool

    model_config = {"from_attributes": True}


class AcademicClassList(BaseModel):
    total: int
    items: list[AcademicClassOut]
