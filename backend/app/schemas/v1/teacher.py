from __future__ import annotations
from datetime import datetime
import uuid
from typing import Optional

from pydantic import BaseModel


class TeacherOut(BaseModel):
    id: int
    user_id: uuid.UUID
    teacher_id: Optional[str] = None
    phone: Optional[str] = None
    department_id: Optional[uuid.UUID] = None
    department_name: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class TeacherAssignDepartment(BaseModel):
    department_id: uuid.UUID


class TeacherList(BaseModel):
    total: int
    items: list[TeacherOut]
