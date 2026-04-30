from __future__ import annotations
from datetime import datetime, date
from typing import Literal, Optional
import uuid
from pydantic import BaseModel, Field


class SessionCreate(BaseModel):
    course_id: uuid.UUID
    schedule_id: uuid.UUID | None = None
    session_date: date
    start_time: datetime
    end_time: datetime | None = None
    checkin_window_start: datetime | None = None
    checkin_window_end: datetime | None = None
    status: Literal["scheduled", "active", "closed"] = "scheduled"


class SessionUpdate(BaseModel):
    status: Literal["scheduled", "active", "closed"]
    end_time: datetime | None = None
    checkin_window_start: datetime | None = None
    checkin_window_end: datetime | None = None


class SessionOut(BaseModel):
    id: uuid.UUID
    course_id: uuid.UUID
    course_code: Optional[str] = None
    course_name: Optional[str] = None
    schedule_id: uuid.UUID | None = None
    session_date: date | None = None
    start_time: datetime
    end_time: datetime | None = None
    checkin_window_start: datetime | None = None
    checkin_window_end: datetime | None = None
    status: str
    mode: Optional[Literal["preset", "flexible", "custom"]] = None
    mapped_status: Optional[str] = None
    can_open: bool = False
    can_close: bool = False
    created_at: datetime
    updated_at: datetime
    room_name: Optional[str] = None
    day_of_week: Optional[int] = None
    teacher_name: Optional[str] = None
    time_slot_name: Optional[str] = None
    present_count: int = 0
    absent_count: int = 0
    total_count: int = 0
    enrolled_count: int = 0

    model_config = {"from_attributes": True}


class SessionWithSchedule(SessionOut):
    schedule: Optional[dict] = None


class SessionList(BaseModel):
    total: int
    items: list[SessionOut]
