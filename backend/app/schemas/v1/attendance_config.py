from __future__ import annotations
import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AttendanceConfigCreate(BaseModel):
    """POST /api/v1/attendance-configs — create per-session attendance config."""
    session_id: uuid.UUID
    room_id: Optional[uuid.UUID] = None
    mode: Optional[str] = Field(default=None, pattern="^(FIXED|FLEXIBLE)$")
    early_allowance: int = Field(default=15, ge=0, le=120)
    late_allowance: int = Field(default=15, ge=0, le=120)


class AttendanceConfigUpdate(BaseModel):
    """PATCH /api/v1/attendance-configs/{session_id} — update config."""
    room_id: Optional[uuid.UUID] = None
    mode: Optional[str] = Field(default=None, pattern="^(FIXED|FLEXIBLE)$")
    early_allowance: Optional[int] = Field(None, ge=0, le=120)
    late_allowance: Optional[int] = Field(None, ge=0, le=120)


class AttendanceConfigResponse(BaseModel):
    """GET /api/v1/attendance-configs/{session_id} — single config."""
    id: uuid.UUID
    session_id: uuid.UUID
    room_id: Optional[uuid.UUID] = None
    mode: Optional[str] = None
    early_allowance: int
    late_allowance: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
