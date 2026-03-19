from __future__ import annotations
from datetime import datetime, time, timezone
from typing import List

from sqlalchemy import Integer, Time, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class TimeSlot(Base):
    """Global time slot / period definition.

    Represents a school period (e.g., Period 1: 07:30-08:15).
    These slots are global and reused across all classrooms.
    """

    __tablename__ = "time_slots"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    period_number: Mapped[int] = mapped_column(Integer, nullable=False)
    start_time: Mapped[time] = mapped_column(Time(timezone=True), nullable=False)
    end_time: Mapped[time] = mapped_column(Time(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
    )

    # ── Relationships ──────────────────────────────────────────
    schedules: Mapped[List["Schedule"]] = relationship(  # noqa: F821
        "Schedule", back_populates="time_slot"
    )

    def __repr__(self) -> str:
        return f"<TimeSlot id={self.id} period={self.period_number} {self.start_time}-{self.end_time}>"
