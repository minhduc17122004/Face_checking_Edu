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
    session_date: date
    start_time: datetime
    end_time: Optional[datetime]
    status: Literal["scheduled", "active", "closed"]
    attendance_count: int = 0
    total_enrolled: int = 0
    can_checkin: bool = Field(
        default=False,
        description="Whether attendance can currently be checked in for this session",
    )

    model_config = {"from_attributes": True}


class RoomSessionList(BaseModel):
    """Paginated room sessions list."""
    total: int
    items: list[RoomSessionResponse]
