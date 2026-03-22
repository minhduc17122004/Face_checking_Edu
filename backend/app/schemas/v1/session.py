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
    course_name: Optional[str] = None
    schedule_id: uuid.UUID | None = None
    session_date: date | None = None
    start_time: datetime
    end_time: datetime | None = None
    checkin_window_start: datetime | None = None
    checkin_window_end: datetime | None = None
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class SessionWithSchedule(SessionOut):
    schedule: Optional[dict] = None


class SessionList(BaseModel):
    total: int
    items: list[SessionOut]
