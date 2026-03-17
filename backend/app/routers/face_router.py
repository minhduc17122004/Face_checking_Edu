from __future__ import annotations
"""Face router — register embeddings and retrieve them per student."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.schemas.face_schema import FaceRegisterRequest, FaceEmbeddingList
from app.services.face_service import FaceService

router = APIRouter(prefix="/face", tags=["Face Embeddings"])


@router.post(
    "/register",
    response_model=FaceEmbeddingList,
    status_code=201,
    summary="Register face embedding(s) for a student",
)
async def register_face(
    body: FaceRegisterRequest,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> FaceEmbeddingList:
    """Store one or more 128-d face embedding vectors for a student.

    Each call **replaces** the student's existing embeddings atomically.
    Pass a single vector in `embedding` or multiple vectors in `embeddings`.
    """
    return await FaceService(db).register(body)


@router.get(
    "/student/{student_id}",
    response_model=FaceEmbeddingList,
    summary="Get all face embeddings for a student",
)
async def get_face_embeddings(
    student_id: int,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> FaceEmbeddingList:
    """Return all stored face embedding records for a specific student."""
    return await FaceService(db).get_embeddings(student_id)
