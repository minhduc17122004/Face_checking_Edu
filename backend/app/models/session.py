from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Index, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.attendance import Attendance
    from app.models.attendance_config import AttendanceConfig
    from app.models.course import Course
    from app.models.schedule import Schedule


class Session(Base):
    """Attendance session - an instance of a scheduled course."""

    __tablename__ = "sessions"
    __table_args__ = (
        CheckConstraint(
            "status IN ('scheduled', 'active', 'closed')",
            name="ck_session_status",
        ),
        Index("ix_sessions_course_start", "course_id", "start_time"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )

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

    session_date: Mapped[date] = mapped_column(Date, nullable=False)

    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_time: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    checkin_window_start: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    checkin_window_end: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    status: Mapped[str] = mapped_column(String(20), default="scheduled", nullable=False)

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

    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )

    course: Mapped["Course"] = relationship("Course", back_populates="sessions")
    schedule: Mapped[Optional["Schedule"]] = relationship(
        "Schedule", back_populates="sessions"
    )
    attendance_records: Mapped[List["Attendance"]] = relationship(
        "Attendance", back_populates="session", cascade="all, delete-orphan"
    )
    attendance_config: Mapped[Optional["AttendanceConfig"]] = relationship(
        "AttendanceConfig", back_populates="session", uselist=False
    )

    def __repr__(self) -> str:
        return (
            f"<Session id={self.id} course={self.course_id} "
            f"start={self.start_time} status={self.status}>"
        )

    @property
    def is_deleted(self) -> bool:
        return self.deleted_at is not None

    @property
    def attendance_mode(self) -> str:
        if self.course and hasattr(self.course, "attendance_mode"):
            return getattr(self.course, "attendance_mode", "preset") or "preset"
        return "preset"

    @property
    def effective_checkin_window_start(self) -> datetime | None:
        if self.course and getattr(self.course, "attendance_mode", None) == "flexible":
            return None
        return self.checkin_window_start

    @property
    def effective_checkin_window_end(self) -> datetime | None:
        if self.course and getattr(self.course, "attendance_mode", None) == "flexible":
            return None
        return self.checkin_window_end

    @property
    def room_name(self) -> str | None:
        if self.course:
            return getattr(self.course, "room_name", None)
        return None

    @property
    def day_of_week(self) -> int | None:
        if self.schedule:
            return getattr(self.schedule, "day_of_week", None)
        return None

    @property
    def time_slot_name(self) -> str | None:
        if not self.schedule or not self.schedule.time_slot:
            return None

        start_period = self.schedule.time_slot.period_number
        end_slot = self.schedule.end_time_slot or self.schedule.time_slot
        end_period = end_slot.period_number

        if start_period == end_period:
            return f"Tiết {start_period}"
        return f"Tiết {start_period}-{end_period}"
