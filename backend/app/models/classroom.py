from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import Optional, List

from sqlalchemy import String, DateTime, ForeignKey, Boolean, Index, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Classroom(Base):
    """Classroom / course entity, created and owned by a teacher.

    Each class holds a set of sessions linked to it.
    """

    __tablename__ = "classes"
    __table_args__ = ()

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )
    class_name: Mapped[str] = mapped_column(String(255), nullable=False)
    subject: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # FK to users (teacher who owns the class)
    teacher_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
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
    teacher: Mapped["User"] = relationship(  # noqa: F821
        "User", back_populates="classes"
    )
    # Note: attendance_records (legacy AttendanceRecord) removed — use Session + Attendance
    classroom_students: Mapped[List["ClassroomStudent"]] = relationship(  # noqa: F821
        "ClassroomStudent", back_populates="classroom", cascade="all, delete-orphan"
    )
    schedules: Mapped[List["Schedule"]] = relationship(  # noqa: F821
        "Schedule", back_populates="classroom", cascade="all, delete-orphan"
    )
    sessions: Mapped[List["Session"]] = relationship(  # noqa: F821
        "Session", back_populates="classroom", cascade="all, delete-orphan"
    )
    devices: Mapped[List["Device"]] = relationship(  # noqa: F821
        "Device", back_populates="classroom"
    )

    def __repr__(self) -> str:
        return f"<Classroom id={self.id} name={self.class_name}>"
