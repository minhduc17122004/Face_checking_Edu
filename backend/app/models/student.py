from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import Optional, List

from sqlalchemy import String, Text, Boolean, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Student(Base):
    """Student profile — uses INTEGER auto-increment PK for Flutter compatibility.

    The Flutter `Employee.fromJson()` parses `id` as `int`, so this model
    intentionally does NOT use UUID as primary key.

    Identity is unified: attendance and face embeddings reference ONLY student_id.
    The academic_class_id field links to the administrative class (lớp chủ quản).
    """

    __tablename__ = "students"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Core identity
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    pin: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)

    # Academic class (lớp chủ quản) — administrative class
    academic_class_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("academic_classes.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Avatar / sync metadata
    avatar_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    has_avatar: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    attachment_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    is_synced: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

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
    user: Mapped[Optional["User"]] = relationship(  # noqa: F821
        "User", back_populates="student_profile"
    )
    face_embeddings: Mapped[List["FaceEmbedding"]] = relationship(  # noqa: F821
        "FaceEmbedding", back_populates="student", cascade="all, delete-orphan"
    )
    # Note: attendance_records (legacy AttendanceRecord) removed — use Attendance instead
    classroom_enrollments: Mapped[List["ClassroomStudent"]] = relationship(  # noqa: F821
        "ClassroomStudent", back_populates="student", cascade="all, delete-orphan"
    )
    attendances: Mapped[List["Attendance"]] = relationship(  # noqa: F821
        "Attendance", back_populates="student"
    )
    academic_class: Mapped[Optional["AcademicClass"]] = relationship(  # noqa: F821
        "AcademicClass", back_populates="students"
    )

    def __repr__(self) -> str:
        return f"<Student id={self.id} name={self.name}>"
