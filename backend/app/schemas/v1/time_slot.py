from __future__ import annotations
from datetime import time
from pydantic import BaseModel, Field


class TimeSlotCreate(BaseModel):
    period_number: int = Field(ge=1)
    start_time: time
    end_time: time


class TimeSlotOut(BaseModel):
    id: int
    period_number: int
    start_time: time
    end_time: time

    model_config = {"from_attributes": True}


class TimeSlotList(BaseModel):
    total: int
    items: list[TimeSlotOut]


class TimeSlotUpdate(BaseModel):
    period_number: int | None = Field(None, ge=1)
    start_time: time | None = None
    end_time: time | None = None
