from __future__ import annotations
from datetime import datetime
import uuid
from typing import Literal, Optional
from pydantic import BaseModel, Field


class AttendanceCreate(BaseModel):
    """POST /api/v1/attendance — unified session-based attendance.

    Supports offline-first with dual timestamps:
    - checkin_time: device-side timestamp
    - sync_time: server-side timestamp (auto-set)
    """
    session_id: uuid.UUID
    student_id: int
    checkin_time: datetime
    sync_time: datetime | None = None
    status: str = Field(default="present", pattern="^(present|late|absent)$")
    confidence: float | None = Field(None, ge=0.0, le=1.0)
    device_id: uuid.UUID | None = None


class CheckinRequest(BaseModel):
    """POST /api/v1/attendance/checkin — real-time device check-in.

    Streamlined schema for device-initiated real-time check-in.
    """
    student_id: int = Field(..., description="Student database ID")
    session_id: uuid.UUID = Field(..., description="Attendance session UUID")
    device_id: uuid.UUID = Field(..., description="Device UUID doing the recognition")
    confidence: float = Field(
        default=1.0,
        ge=0.0,
        le=1.0,
        description="Face recognition confidence score"
    )


class CheckinResponse(BaseModel):
    """Response for real-time check-in."""
    attendance_id: uuid.UUID
    student_id: int
    status: Literal["present", "late"]
    checkin_time: datetime
    message: str


class AttendanceOut(BaseModel):
    id: uuid.UUID
    session_id: uuid.UUID
    student_id: int
    checkin_time: datetime
    sync_time: datetime
    status: str
    confidence: float | None = None
    device_id: uuid.UUID | None = None
    created_at: datetime
    is_deleted: bool

    model_config = {"from_attributes": True}


class AttendanceWithDetails(AttendanceOut):
    student_name: str | None = None
    session_date: datetime | None = None
    classroom_name: str | None = None


class AttendanceList(BaseModel):
    total: int
    items: list[AttendanceOut]


class AttendanceSummary(BaseModel):
    session_id: uuid.UUID
    total_students: int
    present: int
    late: int
    absent: int
    attendance_rate: float
