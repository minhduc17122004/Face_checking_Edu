from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import String, Integer, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.course import Course
    from app.models.device import Device


class Room(Base):
    """Physical room / classroom entity — central domain for location tracking.

    Phase 9: Replaces string-based room fields in schedules and devices.
    Provides a normalized, referentially-integral room domain.

    Relationships:
    - Room → Course: one-to-many (a course has one primary room)
    - Room → Device: one-to-many (a device is installed in one room)

    Usage:
        device.room_id == course.room_id  # anti-cheat FK-based room matching
    """

    __tablename__ = "rooms"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )
    code: Mapped[str] = mapped_column(
        String(50), unique=True, nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    building: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    floor: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    capacity: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

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

    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    updated_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )

    # ── Relationships ──────────────────────────────────────────
    courses: Mapped[List["Course"]] = relationship(
        "Course", back_populates="room"
    )
    devices: Mapped[List["Device"]] = relationship(
        "Device", back_populates="room"
    )

    # ── Accessors ───────────────────────────────────────────────
    @property
    def is_deleted(self) -> bool:
        return self.deleted_at is not None

    @property
    def is_active(self) -> bool:
        return self.deleted_at is None

    def __repr__(self) -> str:
        return f"<Room id={self.id} code={self.code} name={self.name}>"
