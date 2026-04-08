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
    embedding: list  # list[float] or list[list[float]]
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
        {
            "studentId": <int>,
            "studentCode": <str|null>,
            "listFaceEmbedding": [[...], ...],
            "updatedTime": "...",
            "embedding_hash": "<sha256-hex>"
        }
    """

    studentId: int
    studentCode: Optional[str] = Field(
        None,
        description="Student code (MSSV / PIN) — stable across DB resets.",
    )
    personName: Optional[str] = Field(
        None,
        description="Full name of the student for display.",
    )
    listFaceEmbedding: list[list[float]]
    updatedTime: str = Field(
        ..., description="ISO-8601 datetime string of the latest embedding update."
    )
    embedding_hash: str = Field(
        "",
        description="SHA-256 hex digest of the canonical embedding content. "
                    "Clients compare this to skip redundant imports.",
    )

    @classmethod
    def build(
        cls,
        student_id: int,
        embeddings: list,
        updated_at: datetime,
        student_code: str | None = None,
        person_name: str | None = None,
        embedding_hash: str = "",
    ) -> "FaceDataOut":
        """Build from raw ORM data."""
        # Each embedding may be a flat list (single vector) or list of lists
        all_vectors: list[list[float]] = []
        for emb in embeddings:
            data = emb.embedding
            if data and isinstance(data[0], list):
                all_vectors.extend(data)          # already list-of-lists
            else:
                all_vectors.append(data)          # flat list → wrap
        return cls(
            studentId=student_id,
            studentCode=student_code,
            personName=person_name,
            listFaceEmbedding=all_vectors,
            updatedTime=updated_at.isoformat(),
            embedding_hash=embedding_hash,
        )


class FaceExportResponse(RootModel[List[FaceDataOut]]):
    """GET /api/student/export/json — full export payload.

    Flutter iterates this list to load all known face embeddings into
    the on-device recognition engine.
    """

    # Top-level is a JSON array; kept as RootModel for Pydantic v2 compatibility.
