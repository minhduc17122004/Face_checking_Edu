from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional, List

from sqlalchemy import Integer, String, DateTime, ForeignKey, CheckConstraint, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.course import Course
    from app.models.time_slot import TimeSlot
    from app.models.session import Session


class Schedule(Base):
    """Weekly course schedule definition.

    Links a course to a specific day_of_week and time_slot.
    Multiple courses can share the same time_slot (same period).

    Room is accessed via course.room_id (Phase 9), not stored on schedule.
    """

    __tablename__ = "schedules"
    __table_args__ = (
        UniqueConstraint(
            "course_id", "day_of_week", "time_slot_id",
            name="uq_schedule_course_day_slot"
        ),
        CheckConstraint("day_of_week BETWEEN 1 AND 7", name="ck_day_of_week"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    # Renamed: classroom_id → course_id
    course_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("courses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    day_of_week: Mapped[int] = mapped_column(Integer, nullable=False)
    time_slot_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("time_slots.id"), nullable=False
    )

    # Room is no longer stored on Schedule (Phase 9)
    # Schedule inherits room from course via course.room_id
    # Anti-cheat: device.room_id == session.course.room_id

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

    # Audit fields
    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    updated_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )

    # ── Relationships ──────────────────────────────────────────
    # Renamed: classroom → course
    course: Mapped["Course"] = relationship(
        "Course", back_populates="schedules"
    )
    time_slot: Mapped["TimeSlot"] = relationship(
        "TimeSlot", back_populates="schedules"
    )
    sessions: Mapped[List["Session"]] = relationship(
        "Session", back_populates="schedule"
    )

    def __repr__(self) -> str:
        return (
            f"<Schedule id={self.id} course={self.course_id} "
            f"day={self.day_of_week} slot={self.time_slot_id}>"
        )

    @property
    def is_deleted(self) -> bool:
        """Check if schedule is soft-deleted (compatibility accessor)."""
        return self.deleted_at is not None

    @property
    def course_name(self) -> str:
        """Name of the course from Course relation."""
        return self.course.course_name if self.course else "Unknown"
