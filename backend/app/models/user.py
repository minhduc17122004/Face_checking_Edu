from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import String, DateTime, ForeignKey, CheckConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.teacher import Teacher
    from app.models.student import Student
    from app.models.course import Course
    from app.models.student_group import StudentGroup
    from app.models.refresh_token import RefreshToken


class User(Base):
    """Central authentication table for all system users (teacher / student / admin).
    
    Single source of truth for user identity including avatar_url.
    Following Clean Architecture: Auth layer separate from Domain layer.
    """

    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(
            "role IN ('admin', 'teacher', 'student')",
            name="ck_users_role",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )
    email: Mapped[str] = mapped_column(
        String(255), unique=True, nullable=False, index=True
    )
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(
        String(20), nullable=False, default="student"
    )
    # Single source of truth for avatar - no redundancy in Teacher/Student
    avatar_url: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True, default=None
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

    # Audit fields - Uncomment when DB migration adds them
    # created_by: Mapped[Optional[uuid.UUID]] = mapped_column(
    #     UUID(as_uuid=True), nullable=True
    # )
    # updated_by: Mapped[Optional[uuid.UUID]] = mapped_column(
    #     UUID(as_uuid=True), nullable=True
    # )

    # ── Relationships ──────────────────────────────────────────
    teacher_profile: Mapped[Optional["Teacher"]] = relationship(
        "Teacher",
        back_populates="user",
        uselist=False,
        lazy="select",
    )
    student_profile: Mapped[Optional["Student"]] = relationship(
        "Student",
        back_populates="user",
        uselist=False,
        lazy="select",
    )
    # Renamed: classes → courses
    courses: Mapped[List["Course"]] = relationship(
        "Course",
        back_populates="instructor",
        lazy="select",
    )
    # Renamed: advised_classes → advised_groups
    advised_groups: Mapped[List["StudentGroup"]] = relationship(
        "StudentGroup",
        back_populates="advisor",
        lazy="select",
    )
    refresh_tokens: Mapped[List["RefreshToken"]] = relationship(
        "RefreshToken",
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="select",
    )

    @property
    def is_active(self) -> bool:
        """Check if user is active (not soft deleted)."""
        return self.deleted_at is None

    @property
    def display_name(self) -> str:
        """Get display name, falls back to email prefix."""
        return self.full_name or self.email.split("@")[0]

    def __repr__(self) -> str:
        return f"<User id={self.id} email={self.email} role={self.role}>"
