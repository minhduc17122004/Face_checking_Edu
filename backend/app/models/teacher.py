from __future__ import annotations
from typing import TYPE_CHECKING, Optional
import uuid
from datetime import datetime, timezone

from sqlalchemy import String, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.department import Department


class Teacher(Base):
    """Teacher profile — strict 1:1 with User (role='teacher').

    Avatar is stored in User model (single source of truth).
    """

    __tablename__ = "teachers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True,
    )
    teacher_id: Mapped[Optional[str]] = mapped_column(
        String(50), unique=True, nullable=True
    )
    phone: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)

    # Refactored: department (string) → department_id (UUID FK)
    department_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("departments.id", ondelete="SET NULL"),
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

    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )

    # ── Relationships ──────────────────────────────────────────
    user: Mapped["User"] = relationship(
        "User",
        back_populates="teacher_profile",
    )
    department_rel: Mapped[Optional["Department"]] = relationship(
        "Department",
        back_populates="teachers",
    )

    def __repr__(self) -> str:
        return f"<Teacher id={self.id} teacher_id={self.teacher_id}>"

