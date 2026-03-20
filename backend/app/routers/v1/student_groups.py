from __future__ import annotations
"""v1 StudentGroups router — /api/v1/student-groups endpoints."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.student_group_repository import StudentGroupRepository
from app.models.student_group import StudentGroup
from app.schemas.v1.student_group import (
    StudentGroupCreate,
    StudentGroupUpdate,
    StudentGroupOut,
    StudentGroupList,
)

router = APIRouter(prefix="/student-groups", tags=["v1 — StudentGroups"])


@router.post("/", response_model=StudentGroupOut, status_code=status.HTTP_201_CREATED)
async def create_student_group(
    req: StudentGroupCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new student group."""
    repo = StudentGroupRepository(db)
    existing = await repo.get_by_code(req.code)
    if existing and existing.deleted_at is None:
        raise HTTPException(
            status_code=409,
            detail=f"Student group with code '{req.code}' already exists.",
        )

    group = StudentGroup(
        code=req.code,
        name=req.name,
        faculty=req.faculty,
        course_year=req.course_year,
        advisor_id=req.advisor_id,
    )
    db.add(group)
    await db.flush()
    await db.refresh(group)
    return StudentGroupOut.model_validate(group)


@router.get("/", response_model=StudentGroupList)
async def list_student_groups(
    code: str | None = None,
    faculty: str | None = None,
    course_year: str | None = None,
    skip: int = 0,
    limit: int = 200,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List student groups with optional filters."""
    repo = StudentGroupRepository(db)
    items, total = await repo.list(
        code=code,
        faculty=faculty,
        course_year=course_year,
        skip=skip,
        limit=limit,
    )
    return StudentGroupList(
        total=total,
        items=[StudentGroupOut.model_validate(c) for c in items],
    )


@router.get("/{group_id}", response_model=StudentGroupOut)
async def get_student_group(
    group_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single student group."""
    repo = StudentGroupRepository(db)
    group = await repo.get_by_id(group_id)
    if not group or group.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Student group not found.")
    return StudentGroupOut.model_validate(group)


@router.patch("/{group_id}", response_model=StudentGroupOut)
async def update_student_group(
    group_id: uuid.UUID,
    req: StudentGroupUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update a student group."""
    repo = StudentGroupRepository(db)
    group = await repo.get_by_id(group_id)
    if not group or group.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Student group not found.")

    if req.code is not None:
        other = await repo.get_by_code(req.code)
        if other and other.id != group_id and other.deleted_at is None:
            raise HTTPException(status_code=409, detail="Code already in use.")
        group.code = req.code
    if req.name is not None:
        group.name = req.name
    if req.faculty is not None:
        group.faculty = req.faculty
    if req.course_year is not None:
        group.course_year = req.course_year
    if req.advisor_id is not None:
        group.advisor_id = req.advisor_id

    await db.flush()
    await db.refresh(group)
    return StudentGroupOut.model_validate(group)


@router.delete("/{group_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_student_group(
    group_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete a student group."""
    repo = StudentGroupRepository(db)
    group = await repo.get_by_id(group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Student group not found.")
    await repo.soft_delete(group)
    await db.commit()
