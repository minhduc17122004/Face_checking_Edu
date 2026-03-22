from __future__ import annotations
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional, List

import uuid

from sqlalchemy import String, DateTime, ForeignKey, Index, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.teacher import Teacher
    from app.models.course import Course


class Department(Base):
    """Department — organizational unit for grouping teachers and courses.

    A department represents a school/academic department (e.g., "Computer Science",
    "Mathematics"). Teachers are assigned to departments, and courses can optionally
    belong to a department.
    """

    __tablename__ = "departments"
    __table_args__ = (
        Index("ix_departments_code", "code", unique=True),
        Index("ix_departments_name", "name"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    code: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        nullable=False,
        index=True,
    )

    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
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
        DateTime(timezone=True),
        nullable=True,
        index=True,
    )

    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
    )
    updated_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
    )

    # ── Relationships ──────────────────────────────────────────
    teachers: Mapped[List["Teacher"]] = relationship(
        "Teacher",
        back_populates="department_rel",
        lazy="select",
    )

    courses: Mapped[List["Course"]] = relationship(
        "Course",
        back_populates="department",
        lazy="select",
    )

    @property
    def is_deleted(self) -> bool:
        """Check if department is soft-deleted."""
        return self.deleted_at is not None

    def __repr__(self) -> str:
        return f"<Department id={self.id} code={self.code} name={self.name}>"
