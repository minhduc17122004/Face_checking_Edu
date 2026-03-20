from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, UniqueConstraint, Index, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.course import Course
    from app.models.student import Student


class CourseEnrollment(Base):
    """Many-to-many relationship between courses and students.

    This allows a student to enroll in multiple courses and
    a course to have multiple students.

    Renamed from: ClassroomStudent
    Table renamed: classroom_students → course_enrollments
    """

    __tablename__ = "course_enrollments"
    __table_args__ = (
        UniqueConstraint(
            "course_id", "student_id", name="uq_enrollment_course_student"
        ),
        Index(
            "ix_enrollment_course_student", "course_id", "student_id"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    # Renamed: classroom_id → course_id
    course_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("courses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    student_id: Mapped[int] = mapped_column(
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    enrolled_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
    )

    # ── Relationships ──────────────────────────────────────────
    # Renamed: classroom → course
    course: Mapped["Course"] = relationship(
        "Course",
        back_populates="enrollments",
    )
    student: Mapped["Student"] = relationship(
        "Student",
        back_populates="course_enrollments",
    )

    def __repr__(self) -> str:
        return f"<CourseEnrollment course_id={self.course_id} student_id={self.student_id}>"
