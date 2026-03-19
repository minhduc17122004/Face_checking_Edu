from __future__ import annotations
from datetime import datetime
import uuid
from pydantic import BaseModel


class ClassroomStudentCreate(BaseModel):
    classroom_id: uuid.UUID
    student_id: int


class ClassroomStudentOut(BaseModel):
    id: uuid.UUID
    classroom_id: uuid.UUID
    student_id: int
    enrolled_at: datetime

    model_config = {"from_attributes": True}


class ClassroomStudentList(BaseModel):
    total: int
    items: list[ClassroomStudentOut]
