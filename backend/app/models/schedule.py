from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional, List

from sqlalchemy import Integer, String, Boolean, DateTime, ForeignKey, CheckConstraint, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.classroom import Classroom
    from app.models.time_slot import TimeSlot
    from app.models.session import Session


class Schedule(Base):
    """Weekly class schedule definition.

    Links a classroom to a specific day_of_week and time_slot.
    Multiple classrooms can share the same time_slot (same period).
    """

    __tablename__ = "schedules"
    __table_args__ = (
        UniqueConstraint(
            "classroom_id", "day_of_week", "time_slot_id",
            name="uq_schedule_class_day_slot"
        ),
        CheckConstraint("day_of_week BETWEEN 1 AND 7", name="ck_day_of_week"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    classroom_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("classes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    day_of_week: Mapped[int] = mapped_column(Integer, nullable=False)
    time_slot_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("time_slots.id"), nullable=False
    )
    subject_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
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
        "Classroom", back_populates="schedules"
    )
    time_slot: Mapped[TimeSlot] = relationship(
        "TimeSlot", back_populates="schedules"
    )
    sessions: Mapped[List[Session]] = relationship(
        "Session", back_populates="schedule"
    )

    def __repr__(self) -> str:
        return (
            f"<Schedule id={self.id} classroom={self.classroom_id} "
            f"day={self.day_of_week} slot={self.time_slot_id}>"
        )
