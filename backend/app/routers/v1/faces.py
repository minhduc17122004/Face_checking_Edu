from __future__ import annotations
"""v1 Face router — /api/v1/students/{id}/face and /api/v1/courses/{id}/face-embeddings."""
import uuid
import logging
from fastapi import APIRouter, Depends, HTTPException, status, Query
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
logger = logging.getLogger("face_audit")


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
    logger.info("[FACE_REGISTER] user=%s student_id=%d device=%s emb_id=%s",
                user_id, student_id, req.device_id, str(emb.id))
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


@router.delete("/students/{student_id}/face", status_code=status.HTTP_200_OK)
async def delete_face(
    student_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Delete all face embeddings for a student."""
    from app.repositories.face_repository import FaceRepository
    from app.repositories.student_repository import StudentRepository
    
    student = await StudentRepository(db).get_by_id(student_id)
    if not student:
        logger.info("[FACE_DELETE] user=%s student_id=%d result=not_found", user_id, student_id)
        return {"message": "No active face embeddings found (student not found).", "deleted_count": 0}
        
    repo = FaceRepository(db)
    deleted_count = await repo.delete_for_student(student_id)
    await db.commit()
    logger.info("[FACE_DELETE] user=%s student_id=%d deleted_count=%d", user_id, student_id, deleted_count)
    return {"message": f"Deleted {deleted_count} face embeddings.", "deleted_count": deleted_count}



@router.get("/courses/{course_id}/face-embeddings", response_model=FaceBulkExport)
async def export_course_faces(
    course_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Export all active face embeddings for students enrolled in a course.

    Used by devices to sync face data for offline recognition.
    Only returns data for students who have is_active embeddings.
    """
    svc = FaceService(db)
    return await svc.export_for_course(course_id)
@router.get("/sync-status")
async def get_face_sync_status(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/face/sync-status — Track face synchronization status."""
    svc = FaceService(db)
    # Placeholder: return count of students with face vs total
    from sqlalchemy import select, func
    from app.models.student import Student
    from app.models.face_embedding import FaceEmbedding
    
    total_students = await db.scalar(select(func.count(Student.id)).where(Student.deleted_at.is_(None)))
    students_with_face = await db.scalar(
        select(func.count(func.distinct(FaceEmbedding.student_id)))
        .where(FaceEmbedding.deleted_at.is_(None))
    )
    
    return {
        "students_with_face": students_with_face or 0,
        "total_active_students": total_students or 0,
        "sync_needed": (total_students or 0) > (students_with_face or 0)
    }


@router.get("/spoof-logs")
async def get_spoof_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/face/spoof-logs — List potential face spoofing attempts.

    Currently filtered from AttendanceAuditLog with action='spoof'.
    """
    from app.models.attendance_audit_log import AttendanceAuditLog
    from sqlalchemy import select
    
    stmt = (
        select(AttendanceAuditLog)
        .where(AttendanceAuditLog.action == "spoof")
        .order_by(AttendanceAuditLog.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    logs = result.scalars().all()
    
    return {
        "total": len(logs),
        "items": [
            {
                "id": str(log.id),
                "student_id": log.student_id,
                "session_id": str(log.session_id),
                "device_id": str(log.device_id) if log.device_id else None,
                "timestamp": log.created_at.isoformat(),
                "details": "Face recognition confidence below threshold or liveness check failed."
            }
            for log in logs
        ]
    }
