from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional

from sqlalchemy import String, Integer, DateTime, Index, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.student import Student
    from app.models.session import Session
    from app.models.device import Device


class AttendanceAuditLog(Base):
    """Audit log for attendance actions (Phase 9).

    Stores every attendance mutation (check-in, manual, delete) for
    compliance and debugging. Written synchronously after each mutation.

    Phase 9: Uses minutes_diff to derive early/on_time/late status for display.
    """

    __tablename__ = "attendance_audit_logs"
    __table_args__ = (
        Index("ix_attendance_audit_session_student", "session_id", "student_id"),
        Index("ix_attendance_audit_session", "session_id"),
        Index("ix_attendance_audit_student", "student_id"),
        Index("ix_attendance_audit_created", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )

    # Core identifiers
    student_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False, index=True
    )
    device_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("devices.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Action details
    action: Mapped[str] = mapped_column(
        String(20), nullable=False
    )  # "checkin" | "manual" | "delete"

    # Status tracking
    old_status: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    new_status: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)

    # Phase 9: minutes difference at time of check-in
    minutes_diff: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
    )

    def __repr__(self) -> str:
        return (
            f"<AttendanceAuditLog id={self.id} "
            f"student={self.student_id} action={self.action}>"
        )
