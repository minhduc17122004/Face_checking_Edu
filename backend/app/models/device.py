from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import String, Boolean, DateTime, func, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.attendance import Attendance
    from app.models.face_embedding import FaceEmbedding
    from app.models.room import Room
    from app.models.device_request import DeviceRequest


class Device(Base):
    """Device registered for face recognition attendance.

    Hardware registry - stores device information only.
    Anti-cheat and business logic handled by services.

    Responsibilities:
    - Device identification (code, type)
    - Location tracking (room_id FK) — used for anti-cheat room matching
    - Network info (IP, MAC)
    - No course binding — device-room matching replaces device-course binding
    """

    __tablename__ = "devices"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )
    device_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True
    )
    device_name: Mapped[Optional[str]] = mapped_column(
        String(100), nullable=True
    )
    # Room assignment — device is installed in this room (Phase 9)
    # Anti-cheat uses: device.room_id == course.room_id
    room_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("rooms.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    device_type: Mapped[str] = mapped_column(
        String(50), default="tablet", nullable=False
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Phase 9: global access flag + explicit status
    # is_global=true → device can attend in any room
    # is_global=false → device is scoped to room_id
    is_global: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    # Status: ACTIVE, INACTIVE (soft-disable by admin)
    status: Mapped[str] = mapped_column(String(20), default="ACTIVE", nullable=False)

    # Network information
    ip_address: Mapped[Optional[str]] = mapped_column(String(45), nullable=True)
    mac_address: Mapped[Optional[str]] = mapped_column(String(17), nullable=True)

    last_active_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
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

    # Audit fields
    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    updated_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )

    # ── Relationships ──────────────────────────────────────────
    # Device-room coupling via FK (Phase 9): device matching uses room_id FK
    room: Mapped[Optional["Room"]] = relationship(
        "Room", back_populates="devices"
    )
    attendance_records: Mapped[List["Attendance"]] = relationship(
        "Attendance", back_populates="device"
    )
    face_embeddings: Mapped[List["FaceEmbedding"]] = relationship(
        "FaceEmbedding", back_populates="device"
    )

    @property
    def is_online(self) -> bool:
        """Check if device was active recently (within 5 minutes)."""
        if not self.last_active_at:
            return False
        from datetime import timedelta
        return datetime.now(timezone.utc) - self.last_active_at < timedelta(minutes=5)

    def __repr__(self) -> str:
        return f"<Device id={self.id} code={self.device_code} room_id={self.room_id}>"

    @property
    def is_deleted(self) -> bool:
        """Check if device is soft-deleted (compatibility accessor)."""
        return self.deleted_at is not None
