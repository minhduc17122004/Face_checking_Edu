from __future__ import annotations
import uuid
from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field


class DeviceRequestCreate(BaseModel):
    """POST /api/v1/device-requests — submit a device permission request."""
    device_code: str = Field(..., max_length=50)
    device_name: Optional[str] = Field(None, max_length=100)
    room_id: Optional[uuid.UUID] = None  # null = global


class DeviceRequestSubmit(BaseModel):
    """Submit a new device permission request (tablet/admin app)."""
    device_code: str = Field(..., max_length=50)
    device_name: Optional[str] = Field(None, max_length=100)
    room_id: Optional[uuid.UUID] = None


class ApproveRequest(BaseModel):
    """PATCH /api/v1/device-requests/{id}/approve — approve a device request."""
    admin_note: Optional[str] = Field(None, max_length=255)


class RejectRequest(BaseModel):
    """PATCH /api/v1/device-requests/{id}/reject — reject a device request."""
    admin_note: Optional[str] = Field(None, max_length=255)


class DeviceRequestResponse(BaseModel):
    """GET /api/v1/device-requests/{id} — single device request."""
    id: uuid.UUID
    device_code: str
    device_name: Optional[str]
    room_id: Optional[uuid.UUID]
    room_name: Optional[str] = None
    requested_by: Optional[uuid.UUID]
    requester_name: Optional[str] = None
    status: Literal["PENDING", "APPROVED", "REJECTED"]
    reviewed_by: Optional[uuid.UUID]
    reviewer_name: Optional[str] = None
    reviewed_at: Optional[datetime]
    admin_note: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class DeviceRequestList(BaseModel):
    """GET /api/v1/device-requests — paginated list."""
    total: int
    items: list[DeviceRequestResponse]
