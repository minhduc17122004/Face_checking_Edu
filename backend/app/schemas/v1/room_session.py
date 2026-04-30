from __future__ import annotations
import uuid
from datetime import datetime, date
from typing import Literal, Optional

from pydantic import BaseModel, Field


class RoomSessionResponse(BaseModel):
    """GET /api/v1/rooms/{id}/sessions — session info for a room.

    Returns sessions sorted: currently active first, then upcoming by start_time.
    """
    id: uuid.UUID
    course_id: uuid.UUID
    course_name: str
    course_code: Optional[str] = None
    teacher_name: Optional[str] = None
    session_date: date
    start_time: datetime
    end_time: Optional[datetime]
    mode: Optional[Literal["preset", "flexible", "custom"]] = None
    checkin_window_start: Optional[datetime] = None
    checkin_window_end: Optional[datetime] = None
    status: Literal["scheduled", "active", "closed"]
    mapped_status: Literal["NOT_OPEN", "CAN_OPEN", "OPEN", "CLOSED"] = "NOT_OPEN"
    attendance_count: int = 0
    total_enrolled: int = 0
    can_checkin: bool = Field(
        default=False,
        description="Whether attendance can currently be checked in for this session",
    )
    is_closed_early: bool = Field(
        default=False,
        description="True when session was closed early (manually or by custom schedule) while still within its physical time window",
    )

    model_config = {"from_attributes": True}


class RoomSessionList(BaseModel):
    """Paginated room sessions list."""
    total: int
    items: list[RoomSessionResponse]


class RoomActiveSessionResponse(BaseModel):
    """Response for GET /api/v1/rooms/{id}/active-session.

    Contains exactly one active session for the room, or null if none.
    Used by the room selection popup to avoid displaying multiple records.
    """
    session: Optional[RoomSessionResponse] = None

    model_config = {"from_attributes": True}
