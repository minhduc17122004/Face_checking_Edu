from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import String, DateTime, ForeignKey, func, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.student_group import StudentGroup
    from app.models.course_enrollment import CourseEnrollment
    from app.models.face_embedding import FaceEmbedding
    from app.models.attendance import Attendance


class Student(Base):
    """Student profile — strict 1:1 with User, uses INTEGER PK for Flutter compatibility.

    The Flutter `Student.fromJson()` parses `id` as `int`, so this model
    intentionally does NOT use UUID as primary key.

    Identity is unified: attendance and face embeddings reference ONLY student_id.
    The student_group_id field links to the administrative class (lớp chủ quản).
    
    Name and avatar are stored in User model (single source of truth).
    """

    __tablename__ = "students"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    # Strict 1:1 relationship with User - NOT NULL + UNIQUE
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True,
    )

    # Student identification code (MSSV)
    student_code: Mapped[Optional[str]] = mapped_column(
        String(50), unique=True, nullable=True
    )

    # PIN for offline authentication
    pin: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)

    # Renamed: academic_class_id → student_group_id
    student_group_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("student_groups.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # REMOVED REDUNDANT FIELDS (moved to User model):
    # - avatar_url (now in users.avatar_url)
    # - has_avatar (derived from users.avatar_url IS NOT NULL)
    # - attachment_id (infrastructure, not domain)
    # - is_synced (infrastructure, not domain)
    # - name (now in users.full_name)

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
    user: Mapped["User"] = relationship(
        "User",
        back_populates="student_profile",
    )

    # Renamed: AcademicClass → StudentGroup
    student_group: Mapped[Optional["StudentGroup"]] = relationship(
        "StudentGroup",
        back_populates="students",
    )

    # Renamed: classroom_enrollments → course_enrollments
    course_enrollments: Mapped[List["CourseEnrollment"]] = relationship(
        "CourseEnrollment",
        back_populates="student",
        cascade="all, delete-orphan",
    )

    face_embeddings: Mapped[List["FaceEmbedding"]] = relationship(
        "FaceEmbedding",
        back_populates="student",
        cascade="all, delete-orphan",
    )

    attendances: Mapped[List["Attendance"]] = relationship(
        "Attendance",
        back_populates="student",
    )

    @property
    def name(self) -> Optional[str]:
        """Get student name from User (for backward compatibility)."""
        return self.user.full_name if self.user else None

    @property
    def avatar_url(self) -> Optional[str]:
        """Get avatar URL from User (for backward compatibility)."""
        return self.user.avatar_url if self.user else None

    @property
    def has_avatar(self) -> bool:
        """Check if student has avatar (derived)."""
        return self.user.avatar_url is not None if self.user else False

    @property
    def is_active(self) -> bool:
        """Check if student is active (not soft deleted)."""
        return self.deleted_at is None

    def __repr__(self) -> str:
        name = self.name or "Unknown"
        return f"<Student id={self.id} name={name}>"
