from __future__ import annotations
from datetime import datetime
import uuid
from pydantic import BaseModel, Field


class ClassCreate(BaseModel):
    class_name: str = Field(min_length=1, max_length=255)
    subject: str | None = None


class ClassOut(BaseModel):
    id: uuid.UUID
    class_name: str
    subject: str | None = None
    teacher_id: uuid.UUID | None = None
    created_at: datetime
    is_deleted: bool

    model_config = {"from_attributes": True}


class ClassList(BaseModel):
    total: int
    items: list[ClassOut]


class ClassroomStudentDetail(BaseModel):
    """Single student with face status in a classroom."""
    student_id: int
    name: str
    pin: str | None = None
    has_face: bool
    embedding_count: int
    enrolled_at: datetime

    model_config = {"from_attributes": True}


class ClassroomStudentListResponse(BaseModel):
    """GET /api/v1/classrooms/{id}/students — student list with face status."""
    classroom_id: uuid.UUID
    total: int
    students: list[ClassroomStudentDetail]
