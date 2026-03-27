from __future__ import annotations
from typing import Optional
from datetime import datetime
import uuid

from pydantic import BaseModel, Field


class AttendanceCreate(BaseModel):
    """POST /attendance — create a new attendance record via new system.

    Supports offline-first with dual timestamps:
    - checkin_time: device-side timestamp
    - sync_time: server-side timestamp (auto-set)
    """

    session_id: uuid.UUID = Field(..., examples=["550e8400-e29b-41d4-a716-446655440000"])
    student_id: int = Field(..., examples=[1])
    user_id: Optional[uuid.UUID] = Field(None, description="Link to user account (optional)")
    checkin_time: datetime = Field(..., examples=["2026-03-19T08:05:33"])
    sync_time: Optional[datetime] = Field(None, description="Server time (auto-set if not provided)")
    status: str = Field(default="present", pattern="^(present|early|on_time|late|absent)$")
    confidence: Optional[float] = Field(None, ge=0.0, le=1.0, examples=[0.97])
    device_id: Optional[uuid.UUID] = Field(None)
    minutes_diff: Optional[int] = Field(None)


class AttendanceOut(BaseModel):
    """Read response for a single attendance record (new table)."""

    id: uuid.UUID
    session_id: uuid.UUID
    student_id: int
    user_id: Optional[uuid.UUID] = None
    checkin_time: datetime
    sync_time: datetime
    status: str
    confidence: Optional[float]
    device_id: Optional[uuid.UUID]
    created_at: datetime
    is_deleted: bool

    model_config = {"from_attributes": True}


class AttendanceWithDetails(AttendanceOut):
    """Attendance with student and session details."""

    student_name: Optional[str] = None
    session_date: Optional[datetime] = None
    classroom_name: Optional[str] = None


class AttendanceList(BaseModel):
    """Paginated wrapper for GET /attendance."""

    total: int
    items: list[AttendanceOut]


class AttendanceSummary(BaseModel):
    """Summary of attendance for a session."""

    session_id: uuid.UUID
    total_students: int
    present: int
    late: int
    absent: int
    attendance_rate: float
