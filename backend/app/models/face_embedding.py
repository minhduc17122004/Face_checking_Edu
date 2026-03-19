from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional

from sqlalchemy import String, Boolean, DateTime, ForeignKey, Index, func, JSON, Integer
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.student import Student
    from app.models.device import Device


class FaceEmbedding(Base):
    """Stores 128-dimensional face embedding vectors for a student.

    Each student may have multiple embeddings (e.g., different angles/sessions).
    Embeddings are stored as JSONB (list of floats) for efficient retrieval and
    compatibility with the Flutter app's push/pull JSON format:

        { "empId": <int>, "listFaceEmbedding": [[...], [...]], "updatedTime": "..." }

    Uses ONLY student_id for identity — user_id has been removed.
    Supports multiple embeddings per student, active flag, and device tracking.
    """

    __tablename__ = "face_embeddings"
    __table_args__ = (
        Index("ix_face_embeddings_student_id", "student_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )
    # Only student_id — no user_id (unified identity)
    student_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Stores a list of floats (128-d vector) or a list of lists for multi-pose embeddings
    embedding_data: Mapped[list] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), nullable=False
    )
    # Active flag — only active embeddings are used for recognition
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    # Device that captured this embedding
    device_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("devices.id", ondelete="SET NULL"),
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

    # ── Relationships ──────────────────────────────────────────
    student: Mapped[Student] = relationship(
        "Student", back_populates="face_embeddings"
    )
    device: Mapped[Optional[Device]] = relationship(
        "Device", back_populates="face_embeddings"
    )

    def __repr__(self) -> str:
        return f"<FaceEmbedding id={self.id} student_id={self.student_id}>"
