from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import Optional, List

from sqlalchemy import String, Boolean, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class AcademicClass(Base):
    """Academic class (lớp chủ quản) - administrative class.

    Represents the administrative class a student belongs to (e.g., 48K21.1).
    This is separate from Classroom (lớp học phần) which represents course sections.

    Examples:
    - Code: "48K21.1" (K21 = cohort year, 48 = faculty code)
    - Faculty: "Khoa Công Nghệ Thông Tin"
    - Course Year: "K21"
    """

    __tablename__ = "academic_classes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )
    code: Mapped[str] = mapped_column(String(50), unique=True, nullable=False, index=True)
    name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    faculty: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    course_year: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
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

    # Soft delete
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # ── Relationships ──────────────────────────────────────────
    advisor: Mapped[Optional["User"]] = relationship(  # noqa: F821
        "User", back_populates="advised_classes"
    )
    students: Mapped[List["Student"]] = relationship(  # noqa: F821
        "Student", back_populates="academic_class"
    )

    def __repr__(self) -> str:
        return f"<AcademicClass id={self.id} code={self.code}>"
