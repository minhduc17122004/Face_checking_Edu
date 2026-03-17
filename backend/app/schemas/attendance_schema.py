from __future__ import annotations
from typing import Optional
"""Attendance schemas — REST check-in/out and Flutter bulk-sync shapes.

The Flutter app syncs attendance via:
    POST /api/attendance/history/sync_bulk_io

Payload is a list of per-employee sync records, each containing
a list of check-in / check-out entries captured offline on the device.
"""
import uuid
from datetime import datetime

from pydantic import BaseModel, Field


# ──────────────────────────────────────────────────────────────
# REST API schemas
# ──────────────────────────────────────────────────────────────
class CheckinRequest(BaseModel):
    """POST /attendance/checkin — single real-time check-in."""

    student_id: int = Field(..., examples=[1])
    class_id: Optional[uuid.UUID] = Field(None)
    record_type: str = Field("checkin", pattern="^(checkin|checkout)$")
    checkin_time: Optional[datetime] = Field(
        None,
        description="Device-side timestamp; defaults to server time if omitted.",
    )
    confidence: Optional[float] = Field(None, ge=0.0, le=1.0, examples=[0.97])
    device_id: Optional[str] = Field(None, max_length=255)
    latitude: Optional[float] = Field(None)
    longitude: Optional[float] = Field(None)
    image_url: Optional[str] = Field(None)


class AttendanceOut(BaseModel):
    """Read response for a single attendance record."""

    id: uuid.UUID
    student_id: int
    class_id: Optional[uuid.UUID]
    record_type: str
    checkin_time: Optional[datetime]
    sync_time: datetime
    confidence: Optional[float]
    device_id: Optional[str]
    status: str
    latitude: Optional[float]
    longitude: Optional[float]
    image_url: Optional[str]

    model_config = {"from_attributes": True}


class AttendanceList(BaseModel):
    """Paginated wrapper for GET /attendance/history."""

    total: int
    items: list[AttendanceOut]


# ──────────────────────────────────────────────────────────────
# Flutter legacy bulk-sync schemas
# ──────────────────────────────────────────────────────────────
class BulkSyncEntry(BaseModel):
    """A single check-in or check-out entry captured offline by the Flutter app.

    Field names match the Flutter app's JSON serialisation exactly.
    """

    empId: int = Field(..., description="Student integer ID")
    checkTime: str = Field(
        ...,
        description="ISO-8601 datetime string of the device-side scan time.",
        examples=["2024-03-15T08:05:33.000"],
    )
    recordType: str = Field(
        "checkin",
        pattern="^(checkin|checkout)$",
        description="'checkin' or 'checkout'",
    )
    confidence: Optional[float] = Field(None, ge=0.0, le=1.0)
    deviceId: Optional[str] = Field(None)
    latitude: Optional[float] = Field(None)
    longitude: Optional[float] = Field(None)
    imageUrl: Optional[str] = Field(None)
    classId: Optional[str] = Field(
        None, description="UUID string of the class, or null."
    )


class BulkSyncRequest(BaseModel):
    """POST /api/attendance/history/sync_bulk_io

    The Flutter app posts a list of offline-captured records for one or
    more students in a single call.
    """

    records: list[BulkSyncEntry] = Field(
        ..., description="List of offline attendance entries to sync."
    )


class BulkSyncItemResult(BaseModel):
    """Per-record result inside the bulk sync response."""

    empId: int
    checkTime: str
    recordType: str
    status: str = Field(..., description="'synced' | 'duplicate' | 'error'")
    message: Optional[str] = None


class BulkSyncResponse(BaseModel):
    """Response for POST /api/attendance/history/sync_bulk_io

    Flutter checks `synced` count and individual `results` for errors.
    """

    synced: int
    duplicates: int
    errors: int
    results: list[BulkSyncItemResult]
