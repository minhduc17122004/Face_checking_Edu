from __future__ import annotations
from datetime import datetime
from typing import Optional
import uuid
from pydantic import BaseModel, Field


class StudentCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    pin: str | None = Field(None, max_length=10)
    academic_class_id: uuid.UUID | None = None
    has_avatar: bool = False
    attachment_id: str | None = None


class StudentOut(BaseModel):
    id: int
    user_id: uuid.UUID | None = None
    name: str
    pin: str | None = None
    academic_class_id: uuid.UUID | None = None
    avatar_url: str | None = None
    has_avatar: bool
    attachment_id: str | None = None
    is_synced: bool
    created_at: datetime
    updated_at: datetime
    is_deleted: bool

    model_config = {"from_attributes": True}


class StudentList(BaseModel):
    total: int
    items: list[StudentOut]
