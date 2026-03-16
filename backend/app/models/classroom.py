import uuid
from datetime import datetime, timezone

from sqlalchemy import String, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Classroom(Base):
    """Classroom / course entity, created and owned by a teacher.

    Each class holds a set of attendance records linked to it.
    """

    __tablename__ = "classes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )
    class_name: Mapped[str] = mapped_column(String(255), nullable=False)
    subject: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # FK to users (teacher who owns the class)
    teacher_id: Mapped[uuid.UUID | None] = mapped_column(
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

    # ── Relationships ──────────────────────────────────────────
    teacher: Mapped["User"] = relationship(  # noqa: F821
        "User", back_populates="classes"
    )
    attendance_records: Mapped[list["AttendanceRecord"]] = relationship(  # noqa: F821
        "AttendanceRecord", back_populates="classroom", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Classroom id={self.id} name={self.class_name}>"
