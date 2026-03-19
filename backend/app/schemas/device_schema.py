from __future__ import annotations
import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field, ConfigDict


class DeviceBase(BaseModel):
    device_code: str = Field(..., min_length=1, max_length=50)
    room: str = Field(..., min_length=1, max_length=50)
    is_active: bool = True
    device_type: Optional[str] = Field(None, max_length=50, examples=["tablet"])
    ip_address: Optional[str] = Field(None, max_length=45)
    classroom_id: Optional[uuid.UUID] = None


class DeviceCreate(DeviceBase):
    pass


class DeviceUpdate(BaseModel):
    room: Optional[str] = Field(None, max_length=50)
    is_active: Optional[bool] = None
    device_type: Optional[str] = Field(None, max_length=50)
    ip_address: Optional[str] = Field(None, max_length=45)
    classroom_id: Optional[uuid.UUID] = None


class DeviceResponse(DeviceBase):
    id: uuid.UUID
    last_active_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime
    is_deleted: bool

    model_config = ConfigDict(from_attributes=True)


class ScheduleResponse(BaseModel):
    room: str
    schedule: list[dict[str, Any]]
