from __future__ import annotations
"""v1 Face router — /api/v1/students/{id}/face and /api/v1/classrooms/{id}/face-embeddings."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.services.face_service import FaceService
from app.schemas.v1.face import (
    FaceRegisterRequest,
    FaceStatusResponse,
    FaceBulkExport,
)

router = APIRouter(prefix="/face", tags=["v1 — Face"])


@router.post("/students/{student_id}/face", response_model=dict, status_code=status.HTTP_201_CREATED)
async def register_face(
    student_id: int,
    req: FaceRegisterRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Register a face embedding for a student.

    Enforces max 5 embeddings per student. When limit is reached, the oldest
    active embedding is hard-deleted (FIFO eviction).
    """
    svc = FaceService(db)
    emb = await svc.register_face_v1(
        student_id=student_id,
        embedding=req.embedding,
        device_id=req.device_id,
    )
    return {"id": str(emb.id), "student_id": emb.student_id, "message": "Face registered"}


@router.get("/students/{student_id}/face-status", response_model=FaceStatusResponse)
async def get_face_status(
    student_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Check if a student has face embeddings registered."""
    svc = FaceService(db)
    return await svc.get_face_status(student_id)


@router.get("/classrooms/{classroom_id}/face-embeddings", response_model=FaceBulkExport)
async def export_classroom_faces(
    classroom_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Export all active face embeddings for students enrolled in a classroom.

    Used by devices to sync face data for offline recognition.
    Only returns data for students who have is_active embeddings.
    """
    svc = FaceService(db)
    return await svc.export_for_classroom(classroom_id)
