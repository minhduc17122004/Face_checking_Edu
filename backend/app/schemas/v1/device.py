from __future__ import annotations
from datetime import datetime
import uuid
from pydantic import BaseModel, Field


class DeviceCreate(BaseModel):
    device_code: str = Field(min_length=1, max_length=50)
    room: str = Field(min_length=1, max_length=50)
    is_active: bool = True
    device_type: str | None = None
    ip_address: str | None = None
    classroom_id: uuid.UUID | None = None


class DeviceUpdate(BaseModel):
    room: str | None = None
    is_active: bool | None = None
    device_type: str | None = None
    ip_address: str | None = None
    classroom_id: uuid.UUID | None = None


class DeviceResponse(BaseModel):
    id: uuid.UUID
    device_code: str
    room: str
    is_active: bool
    device_type: str | None = None
    ip_address: str | None = None
    classroom_id: uuid.UUID | None = None
    last_active_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    is_deleted: bool

    model_config = {"from_attributes": True}
