from __future__ import annotations
"""v1 Teachers router — /api/v1/teachers endpoints."""
import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.services.teacher_service import TeacherService
from app.schemas.v1.teacher import TeacherOut, TeacherAssignDepartment, TeacherList

router = APIRouter(prefix="/teachers", tags=["v1 — Teachers"])


@router.get("/", response_model=TeacherList)
async def list_teachers(
    department_id: uuid.UUID | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List teachers, optionally filtered by department."""
    svc = TeacherService(db)
    return await svc.list_teachers(department_id=department_id, skip=skip, limit=limit)


@router.get("/{teacher_id}", response_model=TeacherOut)
async def get_teacher(
    teacher_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a teacher by ID."""
    svc = TeacherService(db)
    return await svc.get_teacher(teacher_id)


@router.post("/{teacher_id}/assign-department", response_model=TeacherOut)
async def assign_department(
    teacher_id: int,
    req: TeacherAssignDepartment,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Assign a teacher to a department."""
    svc = TeacherService(db)
    result = await svc.assign_department(teacher_id, req.department_id)
    await db.commit()
    return result


@router.delete("/{teacher_id}/assign-department", response_model=TeacherOut)
async def remove_department_from_teacher(
    teacher_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Remove a teacher from their department."""
    svc = TeacherService(db)
    result = await svc.remove_department(teacher_id)
    await db.commit()
    return result
