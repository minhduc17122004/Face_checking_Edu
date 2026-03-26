from __future__ import annotations
import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, model_validator


class ManualCheckinRequest(BaseModel):
    """POST /api/v1/attendance/check-in — device/admin manual check-in."""
    session_id: Optional[uuid.UUID] = None
    student_id: int
    room_id: Optional[uuid.UUID] = None
    timestamp: Optional[datetime] = None
    checkin_time: Optional[datetime] = None  # legacy alias, defaults to server now
    status: str = "present"
    device_id: Optional[str] = None

    @model_validator(mode="after")
    def validate_target(self) -> "ManualCheckinRequest":
        if self.session_id is None and self.room_id is None:
            raise ValueError("Either session_id or room_id must be provided")
        return self


class ManualCheckinResponse(BaseModel):
    """Response for a manual check-in."""
    attendance_id: uuid.UUID
    student_id: int
    session_id: uuid.UUID
    status: str
    checkin_time: datetime
    minutes_diff: Optional[int] = None
    message: str


class AttendanceRecordResponse(BaseModel):
    """Single attendance record for display in check-in screen."""
    id: uuid.UUID
    student_id: int
    student_name: Optional[str] = None
    student_code: Optional[str] = None
    checkin_time: datetime
    status: str
    minutes_diff: Optional[int] = None
    device_id: Optional[uuid.UUID] = None

    model_config = {"from_attributes": True}


class AttendanceCheckinList(BaseModel):
    """List of attendance records for a session."""
    total: int
    items: list[AttendanceRecordResponse]


class AttendanceSummaryResponse(BaseModel):
    """GET /api/v1/attendance/session/{id}/summary — attendance summary."""
    session_id: uuid.UUID
    course_name: str
    total_enrolled: int
    total_checked_in: int
    present: int       # deprecated alias for total_checked_in
    early: int         # checked in before start_time
    on_time: int       # checked in exactly at start_time
    late: int
    absent: int
    attendance_rate: float


# ── Attendance History (role-based) ──────────────────────────────────────

class AttendanceHistoryItem(BaseModel):
    """Single attendance record for history display."""
    id: uuid.UUID
    student_id: int
    student_name: Optional[str] = None
    student_code: Optional[str] = None
    session_id: uuid.UUID
    session_date: Optional[datetime] = None
    course_name: Optional[str] = None
    course_id: Optional[uuid.UUID] = None
    room_name: Optional[str] = None
    checkin_time: datetime
    status: str
    minutes_diff: Optional[int] = None

    model_config = {"from_attributes": True}


class AttendanceHistoryList(BaseModel):
    """GET /api/v1/attendance/history — paginated list."""
    total: int
    items: list[AttendanceHistoryItem]
