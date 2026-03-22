from __future__ import annotations
from datetime import datetime
import uuid
from typing import Optional

from pydantic import BaseModel, Field


class RoomCreate(BaseModel):
    """POST /api/v1/rooms — create a new room."""

    code: Optional[str] = Field(None, min_length=1, max_length=50)
    name: str = Field(min_length=1, max_length=255)
    building: Optional[str] = Field(None, max_length=100)
    floor: Optional[int] = Field(None, ge=0, le=100)
    capacity: Optional[int] = Field(None, ge=1, le=10000)


class RoomUpdate(BaseModel):
    """PATCH /api/v1/rooms/{id} — update room fields."""

    code: Optional[str] = Field(None, min_length=1, max_length=50)
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    building: Optional[str] = Field(None, max_length=100)
    floor: Optional[int] = Field(None, ge=0, le=100)
    capacity: Optional[int] = Field(None, ge=1, le=10000)


class RoomOut(BaseModel):
    """Read response for a single room."""

    id: uuid.UUID
    code: str
    name: str
    building: Optional[str] = None
    floor: Optional[int] = None
    capacity: Optional[int] = None
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class RoomList(BaseModel):
    """Paginated wrapper for GET /api/v1/rooms."""

    total: int
    items: list[RoomOut]


class AssignRoomRequest(BaseModel):
    """PUT /api/v1/courses/{course_id}/assign-room — assign a room to a course."""

    room_id: uuid.UUID
