from __future__ import annotations
"""Face embedding schemas — v1 API for face registration and device sync."""
import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class FaceRegisterRequest(BaseModel):
    """POST /api/v1/students/{student_id}/face — register a single face embedding."""

    embedding: list[float] = Field(
        ...,
        min_length=128,
        max_length=512,
        description="128-dimensional face embedding vector (MobileFaceNet / ArcFace)",
    )
    device_id: uuid.UUID | None = None


class FaceStatusResponse(BaseModel):
    """GET /api/v1/students/{student_id}/face-status — face registration status."""

    student_id: int
    has_face: bool
    total_embeddings: int


class FaceExportItem(BaseModel):
    """Single student entry in the course face export payload."""

    student_id: int
    embeddings: list[list[float]]
    updated_at: datetime


class FaceBulkExport(BaseModel):
    """GET /api/v1/courses/{id}/face-embeddings — all embeddings for a course."""

    course_id: uuid.UUID
    students: list[FaceExportItem]
    exported_at: datetime


class BulkAttendanceItem(BaseModel):
    """Single attendance record in a bulk device sync payload."""

    session_id: uuid.UUID
    student_id: int
    checkin_time: datetime
    status: str = Field(default="present", pattern="^(present|late|absent)$")
    confidence: float | None = Field(None, ge=0.0, le=1.0)


class BulkAttendanceRequest(BaseModel):
    """POST /api/v1/attendance/bulk — bulk attendance from device."""

    records: list[BulkAttendanceItem] = Field(..., min_length=1, max_length=500)
    device_id: uuid.UUID | None = None


class BulkResultItem(BaseModel):
    """Per-record result in bulk attendance response."""

    session_id: uuid.UUID
    student_id: int
    checkin_time: datetime
    status: str  # "synced" | "duplicate" | "error" | "late"
    message: str | None = None


class BulkAttendanceResponse(BaseModel):
    """Response for bulk attendance submission."""

    synced: int
    duplicates: int
    errors: int
    results: list[BulkResultItem]
