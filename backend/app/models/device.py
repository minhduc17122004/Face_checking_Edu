from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import String, Boolean, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.classroom import Classroom
    from app.models.attendance import Attendance
    from app.models.face_embedding import FaceEmbedding


class Device(Base):
    """Device registered for face recognition attendance.

    Each device is bound to a specific classroom for anti-cheat enforcement.
    Supports tracking of device type, last active time, and IP address.
    """

    __tablename__ = "devices"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )
    device_code: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    room: Mapped[str] = mapped_column(String(50), index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Anti-cheat fields
    device_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    ip_address: Mapped[Optional[str]] = mapped_column(String(45), nullable=True)
    last_active_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # FK to classroom (soft binding - device can be reassigned)
    classroom_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("classes.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
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
    classroom: Mapped[Optional[Classroom]] = relationship(
        "Classroom", back_populates="devices"
    )
    attendance_records: Mapped[List[Attendance]] = relationship(
        "Attendance", back_populates="device"
    )
    face_embeddings: Mapped[List[FaceEmbedding]] = relationship(
        "FaceEmbedding", back_populates="device"
    )

    def __repr__(self) -> str:
        return f"<Device id={self.id} code={self.device_code} room={self.room}>"
