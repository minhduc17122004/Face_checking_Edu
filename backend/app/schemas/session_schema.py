from __future__ import annotations
from typing import Optional, Literal
from datetime import datetime, date
import uuid

from pydantic import BaseModel, Field

from app.schemas.schedule_schema import ScheduleOut


class SessionCreate(BaseModel):
    """POST /sessions — create a new attendance session.

    All times use datetime for timezone and cross-day support.
    session_date is kept for convenience but will be combined with start_time.
    """

    classroom_id: uuid.UUID = Field(..., examples=["550e8400-e29b-41d4-a716-446655440000"])
    schedule_id: Optional[uuid.UUID] = Field(None)
    session_date: date = Field(..., examples=["2026-03-19"])
    start_time: datetime = Field(..., examples=["2026-03-19T07:30:00"])
    end_time: Optional[datetime] = Field(None, examples=["2026-03-19T08:15:00"])
    checkin_start_time: Optional[datetime] = Field(
        None,
        examples=["2026-03-19T07:00:00"],
        description="When check-in opens (optional)"
    )
    checkin_end_time: Optional[datetime] = Field(
        None,
        examples=["2026-03-19T08:00:00"],
        description="When check-in closes (optional)"
    )
    status: Literal["scheduled", "active", "closed"] = Field(
        default="scheduled",
        examples=["scheduled"]
    )


class SessionUpdate(BaseModel):
    """PATCH /sessions/{id} — update session status."""

    status: Literal["scheduled", "active", "closed"] = Field(
        ...,
        examples=["active"]
    )
    end_time: Optional[datetime] = Field(None, examples=["2026-03-19T08:15:00"])
    checkin_start_time: Optional[datetime] = Field(None)
    checkin_end_time: Optional[datetime] = Field(None)


class SessionOut(BaseModel):
    """Read response for a single session.

    Returns session_date computed from start_time for backward compatibility.
    """

    id: uuid.UUID
    classroom_id: uuid.UUID
    schedule_id: Optional[uuid.UUID]
    session_date: Optional[date] = Field(
        None,
        description="Date extracted from start_time for compatibility"
    )
    start_time: datetime
    end_time: Optional[datetime]
    checkin_start_time: Optional[datetime]
    checkin_end_time: Optional[datetime]
    status: str
    created_at: datetime
    updated_at: datetime
    is_deleted: bool

    model_config = {"from_attributes": True}


class SessionWithSchedule(SessionOut):
    """Session with schedule details."""

    schedule: Optional[ScheduleOut] = None


class SessionList(BaseModel):
    """Paginated wrapper for GET /sessions."""

    total: int
    items: list[SessionOut]


class SessionSummary(BaseModel):
    """Summary of a session with attendance statistics."""

    session: SessionOut
    total_students: int
    present_count: int
    late_count: int
    absent_count: int
