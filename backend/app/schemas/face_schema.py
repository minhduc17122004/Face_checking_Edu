from __future__ import annotations
from typing import Optional, List
"""Face embedding schemas — register/retrieve face vectors.

Flutter push/pull contract:
    GET /api/student/export/json
    → [ { "studentId": 1, "listFaceEmbedding": [[...128 floats...], ...], "updatedTime": "..." }, ... ]

    PUT /api/student/update/embedding
    → multipart upload of a .json file containing the same structure.
"""
import uuid
from datetime import datetime

from pydantic import BaseModel, Field, RootModel


# ──────────────────────────────────────────────────────────────
# REST API schemas
# ──────────────────────────────────────────────────────────────
class FaceRegisterRequest(BaseModel):
    """POST /face/register — store a face embedding for a student (REST).

    `embedding` should be a flat list of 128 floats (MobileFaceNet / FaceNet128).
    For multi-pose registration, wrap multiple vectors in a list of lists and
    use the `embeddings` field instead.
    """

    student_id: int = Field(..., examples=[1])
    embedding: Optional[list[float]] = Field(
        None,
        description="Single 128-d float vector.",
        min_length=128,
        max_length=512,
    )
    embeddings: Optional[list[list[float]]] = Field(
        None,
        description="Multiple 128-d float vectors for multi-pose registration.",
    )

    def resolved_embeddings(self) -> list[list[float]]:
        """Return a normalised list-of-lists regardless of which field was given."""
        if self.embeddings:
            return self.embeddings
        if self.embedding:
            return [self.embedding]
        return []


class FaceEmbeddingOut(BaseModel):
    """Read response for a single face embedding record (REST)."""

    id: uuid.UUID
    student_id: int
    embedding_data: list  # list[float] or list[list[float]]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class FaceEmbeddingList(BaseModel):
    """All embeddings for a student, returned by GET /face/student/{student_id}."""

    student_id: int
    count: int
    embeddings: list[FaceEmbeddingOut]


# ──────────────────────────────────────────────────────────────
# Flutter legacy API shapes
# ──────────────────────────────────────────────────────────────
class FaceDataOut(BaseModel):
    """Single student's face data in the Flutter export format.

    Flutter contract:
        { "studentId": <int>, "listFaceEmbedding": [[...], ...], "updatedTime": "..." }
    """

    studentId: int
    listFaceEmbedding: list[list[float]]
    updatedTime: str = Field(
        ..., description="ISO-8601 datetime string of the latest embedding update."
    )

    @classmethod
    def from_orm(cls, student_id: int, embeddings: list, updated_at: datetime) -> "FaceDataOut":
        """Build from raw ORM data."""
        # Each embedding_data may be a flat list (single vector) or list of lists
        all_vectors: list[list[float]] = []
        for emb in embeddings:
            data = emb.embedding_data
            if data and isinstance(data[0], list):
                all_vectors.extend(data)          # already list-of-lists
            else:
                all_vectors.append(data)          # flat list → wrap
        return cls(
            studentId=student_id,
            listFaceEmbedding=all_vectors,
            updatedTime=updated_at.isoformat(),
        )


class FaceExportResponse(RootModel[List[FaceDataOut]]):
    """GET /api/student/export/json — full export payload.

    Flutter iterates this list to load all known face embeddings into
    the on-device recognition engine.
    """

    # Top-level is a JSON array; kept as RootModel for Pydantic v2 compatibility.
