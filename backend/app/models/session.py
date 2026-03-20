from __future__ import annotations
import uuid
from datetime import datetime, date, timezone
from typing import TYPE_CHECKING, Optional, List

from sqlalchemy import String, DateTime, Date, ForeignKey, CheckConstraint, Index, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.course import Course
    from app.models.schedule import Schedule
    from app.models.attendance import Attendance


class Session(Base):
    """Attendance session - an instance of a scheduled course.

    A session represents a specific date when a course takes place.
    It can be:
    - 'scheduled': The session was planned but not yet active
    - 'active': Attendance is currently being taken
    - 'closed': Attendance has ended for this session

    Renamed: classroom_id → course_id

    All times are stored as TIMESTAMP with timezone for proper timezone
    and cross-day logic support.
    """

    __tablename__ = "sessions"
    __table_args__ = (
        CheckConstraint(
            "status IN ('scheduled', 'active', 'closed')",
            name="ck_session_status"
        ),
        Index("ix_sessions_course_start", "course_id", "start_time"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )

    # Renamed: classroom_id → course_id
    course_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("courses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    schedule_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("schedules.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Session date (for easy date queries) - GENERATED ALWAYS AS (start_time::date) STORED
    session_date: Mapped[datetime] = mapped_column(Date, nullable=False)

    # Times are stored as TIMESTAMP for timezone and cross-day support
    start_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    end_time: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Renamed: checkin_start_time → checkin_window_start
    # Renamed: checkin_end_time → checkin_window_end
    checkin_window_start: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    checkin_window_end: Mapped[Optional[datetime]] = mapped_column(
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

    # Soft delete - only deleted_at (removed is_deleted redundancy)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )

    # Audit fields - Uncomment when DB migration adds them
    # created_by: Mapped[Optional[uuid.UUID]] = mapped_column(
    #     UUID(as_uuid=True), nullable=True
    # )
    # updated_by: Mapped[Optional[uuid.UUID]] = mapped_column(
    #     UUID(as_uuid=True), nullable=True
    # )

    # ── Relationships ──────────────────────────────────────────
    # Renamed: classroom → course
    course: Mapped["Course"] = relationship(
        "Course", back_populates="sessions"
    )
    schedule: Mapped[Optional[Schedule]] = relationship(
        "Schedule", back_populates="sessions"
    )
    attendance_records: Mapped[List["Attendance"]] = relationship(
        "Attendance", back_populates="session", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return (
            f"<Session id={self.id} course={self.course_id} "
            f"start={self.start_time} status={self.status}>"
        )
