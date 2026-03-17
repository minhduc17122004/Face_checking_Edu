from __future__ import annotations
from typing import Optional
"""Classroom schemas — create and read responses for the /classes endpoints."""
import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class ClassCreate(BaseModel):
    """POST /classes — create a new classroom."""

    class_name: str = Field(..., min_length=1, max_length=255, examples=["12A1"])
    subject: Optional[str] = Field(None, max_length=255, examples=["Toán"])


class ClassOut(BaseModel):
    """Read response for a single classroom."""

    id: uuid.UUID
    class_name: str
    subject: Optional[str]
    teacher_id: Optional[uuid.UUID]
    created_at: datetime

    model_config = {"from_attributes": True}


class ClassList(BaseModel):
    """Paginated wrapper for GET /classes."""

    total: int
    items: list[ClassOut]
