from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional

from sqlalchemy import String, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.device import Device
    from app.models.room import Room
    from app.models.user import User


class DeviceRequest(Base):
    """Device permission request — tablet/admin mode approval flow (Phase 9).

    When a device wants to do bulk/admin attendance, it submits a request.
    Admins approve or reject. Approved requests grant the device attendance
    permissions scoped to specific rooms or globally.

    Status flow: PENDING → APPROVED → (REJECTED | EXPIRED)
    """

    __tablename__ = "device_requests"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    # Device info
    device_code: Mapped[str] = mapped_column(
        String(50), nullable=False, index=True
    )
    device_name: Mapped[Optional[str]] = mapped_column(
        String(100), nullable=True
    )

    # Target room — null means global (all rooms)
    room_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("rooms.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Requester info
    requested_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Status: PENDING, APPROVED, REJECTED
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="PENDING", index=True
    )

    # Admin response
    reviewed_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    admin_note: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Timestamps
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

    # ── Relationships ──────────────────────────────────────────
    room: Mapped[Optional["Room"]] = relationship(
        "Room", back_populates="device_requests"
    )
    requester: Mapped[Optional["User"]] = relationship(
        "User",
        foreign_keys=[requested_by],
        back_populates="device_requests",
    )
    reviewer: Mapped[Optional["User"]] = relationship(
        "User",
        foreign_keys=[reviewed_by],
        back_populates="device_reviewed_requests",
    )

    def __repr__(self) -> str:
        return (
            f"<DeviceRequest id={self.id} device={self.device_code} "
            f"status={self.status}>"
        )
