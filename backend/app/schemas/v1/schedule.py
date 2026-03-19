from __future__ import annotations
from datetime import datetime
import uuid
from pydantic import BaseModel, Field


class ScheduleCreate(BaseModel):
    classroom_id: uuid.UUID
    day_of_week: int = Field(ge=1, le=7)
    time_slot_id: int
    subject_name: str | None = None


class ScheduleOut(BaseModel):
    id: uuid.UUID
    classroom_id: uuid.UUID
    day_of_week: int
    time_slot_id: int
    subject_name: str | None = None
    created_at: datetime
    is_deleted: bool

    model_config = {"from_attributes": True}


class ScheduleWithTimeSlot(ScheduleOut):
    time_slot: dict | None = None


class ScheduleList(BaseModel):
    total: int
    items: list[ScheduleOut]
