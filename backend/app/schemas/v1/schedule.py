from __future__ import annotations
from datetime import datetime
import uuid
from typing import Optional
from pydantic import BaseModel, Field


class ScheduleCreate(BaseModel):
    course_id: uuid.UUID
    day_of_week: int = Field(ge=1, le=7)
    time_slot_id: int


class ScheduleUpdate(BaseModel):
    """PUT /api/v1/schedules/{id} — update an existing schedule."""

    day_of_week: Optional[int] = Field(None, ge=1, le=7)
    time_slot_id: Optional[int] = None


class ScheduleOut(BaseModel):
    id: uuid.UUID
    course_id: uuid.UUID
    day_of_week: int
    time_slot_id: int
    created_at: datetime

    model_config = {"from_attributes": True}


class ScheduleWithTimeSlot(ScheduleOut):
    time_slot: dict | None = None


class ScheduleList(BaseModel):
    total: int
    items: list[ScheduleOut]
