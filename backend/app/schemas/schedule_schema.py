from __future__ import annotations
from typing import Optional

import uuid
from datetime import datetime
from pydantic import BaseModel, Field

from app.schemas.time_slot_schema import TimeSlotOut


class ScheduleCreate(BaseModel):
    """POST /schedules — create a new schedule entry."""

    course_id: uuid.UUID = Field(..., examples=["550e8400-e29b-41d4-a716-446655440000"])
    day_of_week: int = Field(..., ge=1, le=7, examples=[1])
    time_slot_id: int = Field(..., ge=1, examples=[1])
    room: Optional[str] = Field(None, max_length=255, examples=["Room 101"])


class ScheduleOut(BaseModel):
    """Read response for a single schedule entry."""

    id: uuid.UUID
    course_id: uuid.UUID
    day_of_week: int
    time_slot_id: int
    room: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class ScheduleWithTimeSlot(ScheduleOut):
    """Schedule with time slot details."""

    time_slot: Optional[TimeSlotOut] = None


class ScheduleList(BaseModel):
    """Paginated wrapper for GET /schedules."""

    total: int
    items: list[ScheduleOut]
