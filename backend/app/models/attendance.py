from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional

from sqlalchemy import String, Float, Integer, DateTime, ForeignKey, UniqueConstraint, CheckConstraint, Index, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.session import Session
    from app.models.student import Student
    from app.models.device import Device


class Attendance(Base):
    """Session-based attendance record.

    Each record represents a student's attendance within a specific session.
    Uses ONLY student_id for identity.

    Design:
    - Offline-first: checkin_time (device clock) + sync_time (server clock)
    - Anti-cheat: device validation, time window enforcement
    - UNIQUE constraint on (session_id, student_id) prevents duplicate check-ins
    """

    __tablename__ = "attendance"
    __table_args__ = (
        UniqueConstraint(
            "session_id", "student_id", name="uq_attendance_session_student"
        ),
        CheckConstraint(
            "status IN ('present', 'late', 'absent')",
            name="ck_attendance_status",
        ),
        Index("ix_attendance_session_student", "session_id", "student_id"),
        Index("ix_attendance_checkin_time", "checkin_time"),
        Index("ix_attendance_status", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )

    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Only student_id — no user_id (unified identity)
    student_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Dual timestamps for offline-first support
    checkin_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    sync_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
    )

    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="present"
    )

    # Face recognition metadata
    confidence: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    device_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("devices.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
    )

    # Soft delete - only deleted_at (removed is_deleted redundancy)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )

    # ── Relationships ──────────────────────────────────────────
    session: Mapped["Session"] = relationship(
        "Session", back_populates="attendance_records"
    )
    student: Mapped["Student"] = relationship(
        "Student", back_populates="attendances"
    )
    device: Mapped[Optional["Device"]] = relationship(
        "Device", back_populates="attendance_records"
    )

    def __repr__(self) -> str:
        return (
            f"<Attendance id={self.id} session={self.session_id} "
            f"student={self.student_id} status={self.status}>"
        )
