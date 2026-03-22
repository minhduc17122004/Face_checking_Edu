from __future__ import annotations
from datetime import datetime
import uuid
from pydantic import BaseModel, Field


class DeviceCreate(BaseModel):
    device_code: str = Field(min_length=1, max_length=50)
    room_id: uuid.UUID | None = None
    is_active: bool = True
    device_type: str | None = None
    ip_address: str | None = None


class DeviceUpdate(BaseModel):
    room_id: uuid.UUID | None = None
    is_active: bool | None = None
    device_type: str | None = None
    ip_address: str | None = None


class DeviceResponse(BaseModel):
    id: uuid.UUID
    device_code: str
    room_id: uuid.UUID | None = None
    is_active: bool
    device_type: str | None = None
    ip_address: str | None = None
    last_active_at: datetime | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
