from __future__ import annotations
"""v1 Students router — /api/v1/students endpoints."""
import uuid as _uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.student_repository import StudentRepository
from app.schemas.v1.student import StudentCreate, StudentOut, StudentList

router = APIRouter(prefix="/students", tags=["v1 — Students"])


@router.post("/", response_model=StudentOut, status_code=status.HTTP_201_CREATED)
async def create_student(
    req: StudentCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new student."""
    repo = StudentRepository(db)
    student = await repo.create(
        name=req.name,
        pin=req.pin,
        has_avatar=req.has_avatar,
        attachment_id=req.attachment_id,
    )
    if req.academic_class_id:
        student.academic_class_id = req.academic_class_id
    await db.commit()
    return StudentOut.model_validate(student)


@router.get("/", response_model=StudentList)
async def list_students(
    skip: int = Query(0, ge=0),
    limit: int = Query(500, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all students."""
    repo = StudentRepository(db)
    items = await repo.get_all(skip=skip, limit=limit)
    total = await repo.count()
    return StudentList(total=total, items=[StudentOut.model_validate(s) for s in items])


@router.get("/{student_id}", response_model=StudentOut)
async def get_student(
    student_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single student by integer ID."""
    repo = StudentRepository(db)
    student = await repo.get_by_id(student_id)
    if not student or student.is_deleted:
        raise HTTPException(status_code=404, detail=f"Student {student_id} not found.")
    return StudentOut.model_validate(student)
