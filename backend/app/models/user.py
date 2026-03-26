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
    from app.models.device_request import DeviceRequest


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
    # Courses are now owned by Teacher, not directly by User
    # Course → Teacher → User (access via course.teacher.user)
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
    device_requests: Mapped[List["DeviceRequest"]] = relationship(
        "DeviceRequest",
        foreign_keys="DeviceRequest.requested_by",
        back_populates="requester",
        lazy="select",
    )
    device_reviewed_requests: Mapped[List["DeviceRequest"]] = relationship(
        "DeviceRequest",
        foreign_keys="DeviceRequest.reviewed_by",
        back_populates="reviewer",
        lazy="select",
    )

    @property
    def is_active(self) -> bool:
        """Check if user is active (not soft deleted)."""
        return self.deleted_at is None

    @property
    def is_deleted(self) -> bool:
        """Check if user is soft-deleted (compatibility accessor)."""
        return self.deleted_at is not None

    @property
    def checkin_code(self) -> str | None:
        try:
            if self.role == "teacher" and self.teacher_profile:
                return self.teacher_profile.teacher_id
            if self.role == "student" and self.student_profile:
                return self.student_profile.student_code
        except Exception:
            pass
        return None

    @property
    def student_code(self) -> str | None:
        return self.checkin_code

    @property
    def class_name(self) -> str | None:
        """Return class/group name for students only. Teachers have no class."""
        try:
            if self.role == "student" and self.student_profile and self.student_profile.student_group:
                return self.student_profile.student_group.name
        except Exception:
            pass
        return None

    @property
    def department_name(self) -> str | None:
        """Return department name for teacher or student's group department."""
        try:
            if self.role == "teacher" and self.teacher_profile and self.teacher_profile.department_rel:
                return self.teacher_profile.department_rel.name
            if self.role == "student" and self.student_profile and self.student_profile.student_group and self.student_profile.student_group.department:
                return self.student_profile.student_group.department.name
        except Exception:
            pass
        return None

    @property
    def display_name(self) -> str:
        """Get display name, falls back to email prefix."""
        return self.full_name or self.email.split("@")[0]

    def __repr__(self) -> str:
        return f"<User id={self.id} email={self.email} role={self.role}>"
