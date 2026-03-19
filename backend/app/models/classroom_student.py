from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import Integer, DateTime, ForeignKey, UniqueConstraint, Index, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.classroom import Classroom
    from app.models.student import Student


class ClassroomStudent(Base):
    """Many-to-many relationship between classrooms and students.

    This allows a student to belong to multiple classrooms and
    a classroom to have multiple students.
    """

    __tablename__ = "classroom_students"
    __table_args__ = (
        UniqueConstraint("classroom_id", "student_id", name="uq_classroom_student"),
        Index("ix_classroom_students_class_student", "classroom_id", "student_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    classroom_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("classes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    student_id: Mapped[int] = mapped_column(
        Integer,
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
    classroom: Mapped[Classroom] = relationship(
        "Classroom", back_populates="classroom_students"
    )
    student: Mapped[Student] = relationship(
        "Student", back_populates="classroom_enrollments"
    )

    def __repr__(self) -> str:
        return f"<ClassroomStudent classroom_id={self.classroom_id} student_id={self.student_id}>"
