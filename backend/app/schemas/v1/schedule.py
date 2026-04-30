from __future__ import annotations
from datetime import datetime
import uuid
from typing import Optional

from pydantic import BaseModel, Field

from app.schemas.v1.time_slot import TimeSlotOut


class ScheduleCreate(BaseModel):
    course_id: uuid.UUID
    day_of_week: int = Field(ge=1, le=7)
    time_slot_id: int
    end_time_slot_id: Optional[int] = Field(None, ge=1)


class ScheduleUpdate(BaseModel):
    """PUT /api/v1/schedules/{id} — update an existing schedule."""

    day_of_week: Optional[int] = Field(None, ge=1, le=7)
    time_slot_id: Optional[int] = None
    end_time_slot_id: Optional[int] = Field(None, ge=1)


class ScheduleOut(BaseModel):
    id: uuid.UUID
    course_id: uuid.UUID
    day_of_week: int
    time_slot_id: int
    end_time_slot_id: Optional[int] = None
    course_name: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ScheduleWithTimeSlot(ScheduleOut):
    """Response that includes the joined time_slot object."""

    time_slot: Optional[TimeSlotOut] = None
    end_time_slot: Optional[TimeSlotOut] = None


class ScheduleList(BaseModel):
    """Paginated collection of simple schedules."""
    total: int
    items: list[ScheduleOut]


class ScheduleListWithTimeSlot(BaseModel):
    """Paginated collection of schedules with joined time_slots."""
    total: int
    items: list[ScheduleWithTimeSlot]
