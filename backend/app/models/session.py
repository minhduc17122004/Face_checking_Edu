from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional, List

from sqlalchemy import String, DateTime, ForeignKey, CheckConstraint, Boolean, Index, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.classroom import Classroom
    from app.models.schedule import Schedule
    from app.models.attendance import Attendance


class Session(Base):
    """Actual attendance session - an instance of a scheduled class.

    A session represents a specific date when a class takes place.
    It can be:
    - 'scheduled': The session was planned but not yet active
    - 'active': Attendance is currently being taken
    - 'closed': Attendance has ended for this session

    All times are stored as TIMESTAMP with timezone for proper timezone
    and cross-day logic support.
    """

    __tablename__ = "sessions"
    __table_args__ = (
        CheckConstraint(
            "status IN ('scheduled', 'active', 'closed')",
            name="ck_session_status"
        ),
        Index("ix_sessions_classroom_start", "classroom_id", "start_time"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )
    classroom_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("classes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    schedule_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("schedules.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Times are stored as TIMESTAMP (not just TIME) for timezone and cross-day support
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_time: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Check-in window (for anti-cheat and late detection)
    checkin_start_time: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    checkin_end_time: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    status: Mapped[str] = mapped_column(
        String(20), default="scheduled", nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=lambda: datetime.now(timezone.utc),
        default=lambda: datetime.now(timezone.utc),
    )

    # Soft delete
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # ── Relationships ──────────────────────────────────────────
    classroom: Mapped[Classroom] = relationship(
        "Classroom", back_populates="sessions"
    )
    schedule: Mapped[Optional[Schedule]] = relationship(
        "Schedule", back_populates="sessions"
    )
    attendance_records: Mapped[List[Attendance]] = relationship(
        "Attendance", back_populates="session", cascade="all, delete-orphan"
    )

    @property
    def session_date(self) -> Optional[datetime]:
        """Return just the date portion of start_time for compatibility."""
        return self.start_time.date() if self.start_time else None

    def __repr__(self) -> str:
        return (
            f"<Session id={self.id} classroom={self.classroom_id} "
            f"start={self.start_time} status={self.status}>"
        )
