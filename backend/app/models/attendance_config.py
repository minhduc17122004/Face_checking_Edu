from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional

from sqlalchemy import String, Integer, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.session import Session


class AttendanceConfig(Base):
    """Per-session attendance tolerance configuration (Phase 9).

    Allows administrators to set early/late allowance per session instead of
    using hardcoded defaults. A session without config falls back to defaults.

    Usage:
        effective_start = session.start_time - config.early_allowance
        effective_end   = session.end_time   + config.late_allowance
        Check-in valid when: effective_start <= NOW <= effective_end
    """

    __tablename__ = "attendance_configs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    # One config per session
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sessions.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )

    # Tolerance in minutes
    # early_allowance: student can check in this many minutes BEFORE start_time
    early_allowance: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=15,
    )
    # late_allowance: student can check in this many minutes AFTER start_time
    # before being marked as late/absent
    late_allowance: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=15,
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

    # ── Relationships ──────────────────────────────────────────
    session: Mapped["Session"] = relationship(
        "Session", back_populates="attendance_config"
    )

    def __repr__(self) -> str:
        return (
            f"<AttendanceConfig id={self.id} session={self.session_id} "
            f"early={self.early_allowance}m late={self.late_allowance}m>"
        )
