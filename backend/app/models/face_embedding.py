from __future__ import annotations
import uuid
from datetime import datetime, timezone

from sqlalchemy import String, Float, Boolean, DateTime, ForeignKey, func, JSON, Integer
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class FaceEmbedding(Base):
    """Stores 128-dimensional face embedding vectors for a student.

    Each student may have multiple embeddings (e.g., different angles/sessions).
    Embeddings are stored as JSONB (list of floats) for efficient retrieval and
    compatibility with the Flutter app's push/pull JSON format:

        { "empId": <int>, "listFaceEmbedding": [[...], [...]], "updatedTime": "..." }
    """

    __tablename__ = "face_embeddings"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )
    student_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Stores a list of floats (128-d vector) or a list of lists for multi-pose embeddings
    embedding_data: Mapped[list] = mapped_column(JSON().with_variant(JSONB, "postgresql"), nullable=False)

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
    student: Mapped["Student"] = relationship(  # noqa: F821
        "Student", back_populates="face_embeddings"
    )

    def __repr__(self) -> str:
        return f"<FaceEmbedding id={self.id} student_id={self.student_id}>"
