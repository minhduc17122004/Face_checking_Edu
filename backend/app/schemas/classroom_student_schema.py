from __future__ import annotations
from typing import Optional

import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class ClassroomStudentCreate(BaseModel):
    """POST /classroom-students — enroll a student in a classroom."""

    classroom_id: uuid.UUID = Field(..., examples=["550e8400-e29b-41d4-a716-446655440000"])
    student_id: int = Field(..., examples=[1])


class ClassroomStudentOut(BaseModel):
    """Read response for a classroom-student enrollment."""

    id: uuid.UUID
    classroom_id: uuid.UUID
    student_id: int
    enrolled_at: datetime

    model_config = {"from_attributes": True}


class ClassroomStudentList(BaseModel):
    """Paginated wrapper for GET /classroom-students."""

    total: int
    items: list[ClassroomStudentOut]
