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
    from app.models.student import Student


class StudentGroup(Base):
    """Student Group (lớp chủ quản) - administrative class.

    Represents the administrative class a student belongs to (e.g., 48K21.1).
    This is separate from Course (lớp học phần) which represents course sections.

    Renamed from: academic_classes
    Purpose: Clear domain naming

    Examples:
    - Code: "48K21.1" (K21 = cohort year, 48 = faculty code)
    - Faculty: "Khoa Công Nghệ Thông Tin"
    - Course Year: "K21"
    """

    __tablename__ = "student_groups"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )
    code: Mapped[str] = mapped_column(
        String(50), unique=True, nullable=False, index=True
    )
    name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    faculty: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    course_year: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)

    # Renamed: advisor_id (same as before)
    advisor_id: Mapped[Optional[uuid.UUID]] = mapped_column(
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
    # Updated: advised_classes → advised_groups
    advisor: Mapped[Optional["User"]] = relationship(
        "User",
        back_populates="advised_groups",
    )

    # Updated: academic_class → student_group
    students: Mapped[List["Student"]] = relationship(
        "Student",
        back_populates="student_group",
    )

    @property
    def student_count(self) -> int:
        """Get total active students in this group."""
        return len([s for s in self.students if s.deleted_at is None])

    def __repr__(self) -> str:
        return f"<StudentGroup id={self.id} code={self.code}>"
