from __future__ import annotations
from datetime import datetime
import uuid
from typing import Optional

from pydantic import BaseModel, Field


class DepartmentCreate(BaseModel):
    code: str = Field(min_length=1, max_length=50)
    name: str = Field(min_length=1, max_length=255)


class DepartmentUpdate(BaseModel):
    code: Optional[str] = Field(None, min_length=1, max_length=50)
    name: Optional[str] = Field(None, min_length=1, max_length=255)


class DepartmentOut(BaseModel):
    id: uuid.UUID
    code: str
    name: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class DepartmentWithStats(DepartmentOut):
    teacher_count: int = 0
    student_count: int = 0


class DepartmentList(BaseModel):
    total: int
    items: list[DepartmentOut]
