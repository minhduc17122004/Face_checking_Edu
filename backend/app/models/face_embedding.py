from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional

from sqlalchemy import Float, Boolean, DateTime, ForeignKey, Index, func, Integer, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.student import Student
    from app.models.device import Device


class FaceEmbedding(Base):
    """Stores 128-dimensional face embedding vectors for a student.

    Each student may have multiple embeddings (e.g., different angles/sessions).
    Embeddings are stored using pgvector for efficient similarity search.

    Design decisions:
    - Uses ONLY student_id for identity (no user_id)
    - Supports multiple embeddings per student
    - Active flag for enabling/disabling embeddings
    - Device tracking for audit purposes
    - Quality score for face quality estimation

    Note: embedding column uses JSON for compatibility.
    For pgvector support, modify to:
        from sqlalchemy import ARRAY, Float
        embedding = mapped_column(ARRAY(Float), nullable=False)
    Or use pgvector extension with custom type.
    """

    __tablename__ = "face_embeddings"
    __table_args__ = (
        Index("ix_face_embeddings_student", "student_id"),
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

    # Embedding data - stored as JSON list of floats (128-d vector)
    # For production with pgvector, use:
    # embedding = mapped_column(VECTOR(128), nullable=False)
    embedding: Mapped[list] = mapped_column(
        JSON, nullable=False
    )

    # Active flag — only active embeddings are used for recognition
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, nullable=False, index=True
    )

    # Quality estimation (0.0 - 1.0)
    quality_score: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True
    )

    # Device that captured this embedding
    device_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("devices.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # When embedding was captured
    captured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
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

    # ── Relationships ──────────────────────────────────────────
    student: Mapped["Student"] = relationship(
        "Student", back_populates="face_embeddings"
    )
    device: Mapped[Optional["Device"]] = relationship(
        "Device", back_populates="face_embeddings"
    )

    @property
    def is_high_quality(self) -> bool:
        """Check if embedding meets quality threshold."""
        return self.quality_score is not None and self.quality_score >= 0.7

    def __repr__(self) -> str:
        return f"<FaceEmbedding id={self.id} student_id={self.student_id}>"
