from __future__ import annotations
import uuid
from datetime import date, datetime, timezone
from typing import TYPE_CHECKING, List, Literal, Optional

from sqlalchemy import Date, String, DateTime, ForeignKey, Integer, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

AttendanceMode = Literal["preset", "flexible"]

if TYPE_CHECKING:
    from app.models.teacher import Teacher
    from app.models.course_enrollment import CourseEnrollment
    from app.models.schedule import Schedule
    from app.models.session import Session
    from app.models.device import Device
    from app.models.department import Department
    from app.models.room import Room


class Course(Base):
    """Course / teaching class entity, created and owned by a teacher.

    Represents a course section (lớp học phần) that students enroll in.
    Each course holds a set of sessions linked to it.
    """

    __tablename__ = "courses"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    course_name: Mapped[str] = mapped_column(String(255), nullable=False)

    course_code: Mapped[Optional[str]] = mapped_column(
        String(50), nullable=True
    )

    # Course belongs to a teacher (domain entity), not directly to a User
    teacher_id: Mapped[Optional[int]] = mapped_column(
        Integer,
        ForeignKey("teachers.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Optional department association
    department_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("departments.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Room assignment — primary room for this course (Phase 9)
    # Anti-cheat uses: device.room_id == course.room_id
    room_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("rooms.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Attendance config — Literal types enforced at DB level via CHECK constraint
    attendance_mode: Mapped[str] = mapped_column(
        String(20), default="preset", nullable=False
    )
    custom_window_start_minutes: Mapped[int] = mapped_column(
        Integer, default=0
    )
    custom_window_end_minutes: Mapped[int] = mapped_column(
        Integer, default=30
    )

    # Total number of sessions planned for the course
    total_sessions: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True
    )
    
    # Number of credits for the course
    credits: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True
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

    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    updated_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )

    # ── Relationships ──────────────────────────────────────────
    teacher: Mapped[Optional["Teacher"]] = relationship(
        "Teacher",
        back_populates="courses",
    )

    department: Mapped[Optional["Department"]] = relationship(
        "Department",
        back_populates="courses",
    )

    room: Mapped[Optional["Room"]] = relationship(
        "Room",
        back_populates="courses",
    )

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

    @property
    def enrolled_student_count(self) -> int:
        """Get total enrolled students in this course."""
        return len([e for e in self.enrollments])

    @property
    def teacher_name(self) -> Optional[str]:
        """Full name of the teacher (from Teacher → User relationship)."""
        if self.teacher is None:
            return None
        return getattr(self.teacher.user, "full_name", None) or getattr(
            self.teacher.user, "name", None
        )

    @property
    def department_name(self) -> Optional[str]:
        """Name of the department (from Department relationship)."""
        if self.department is None:
            return None
        return self.department.name

    @property
    def room_name(self) -> Optional[str]:
        """Display name of the room (from Room relationship)."""
        if self.room is None:
            return None
        return getattr(self.room, "display_name", None) or getattr(
            self.room, "name", None
        )

    @property
    def is_active(self) -> bool:
        """Check if course is active (not soft deleted)."""
        return self.deleted_at is None

    @property
    def is_deleted(self) -> bool:
        """Check if course is soft-deleted (compatibility accessor)."""
        return self.deleted_at is not None

    @property
    def is_course_active_now(self) -> bool:
        """Compatibility accessor."""
        return True

    def __repr__(self) -> str:
        return f"<Course id={self.id} name={self.course_name}>"
