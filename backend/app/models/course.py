from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import String, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.course_enrollment import CourseEnrollment
    from app.models.schedule import Schedule
    from app.models.session import Session
    from app.models.device import Device


class Course(Base):
    """Course / teaching class entity, created and owned by a teacher.

    Represents a course section (lớp học phần) that students enroll in.
    Each course holds a set of sessions linked to it.

    Renamed from: Classroom (but table name is "classes" → "courses")
    Purpose: Clear domain naming - Course for teaching, Group for administrative
    """

    __tablename__ = "courses"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    # Renamed: class_name → course_name
    course_name: Mapped[str] = mapped_column(String(255), nullable=False)
    subject: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Course code for registration
    course_code: Mapped[Optional[str]] = mapped_column(
        String(50), nullable=True
    )

    # Renamed: teacher_id → instructor_id
    instructor_id: Mapped[Optional[uuid.UUID]] = mapped_column(
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
    # Updated: teacher → instructor
    instructor: Mapped[Optional["User"]] = relationship(
        "User",
        back_populates="courses",
    )

    # Updated: classroom_students → course_enrollments
    enrollments: Mapped[List["CourseEnrollment"]] = relationship(
        "CourseEnrollment",
        back_populates="course",
        cascade="all, delete-orphan",
    )

    schedules: Mapped[List["Schedule"]] = relationship(
        "Schedule",
        back_populates="course",
        cascade="all, delete-orphan",
    )

    sessions: Mapped[List["Session"]] = relationship(
        "Session",
        back_populates="course",
        cascade="all, delete-orphan",
    )

    devices: Mapped[List["Device"]] = relationship(
        "Device",
        back_populates="course",
    )

    @property
    def enrolled_student_count(self) -> int:
        """Get total enrolled students in this course."""
        return len([e for e in self.enrollments])

    @property
    def is_active(self) -> bool:
        """Check if course is active (not soft deleted)."""
        return self.deleted_at is None

    def __repr__(self) -> str:
        return f"<Course id={self.id} name={self.course_name}>"
