from __future__ import annotations
import uuid
from typing import Any
from pydantic import BaseModel, ConfigDict

class DeviceBase(BaseModel):
    device_code: str
    room: str
    is_active: bool = True

class DeviceCreate(DeviceBase):
    pass

class DeviceResponse(DeviceBase):
    id: uuid.UUID
    
    model_config = ConfigDict(from_attributes=True)

class ScheduleResponse(BaseModel):
    room: str
    schedule: list[dict[str, Any]]
