from __future__ import annotations
"""Student Group router — administrative class management."""
import uuid
from typing import Optional
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.student_group import StudentGroup
from app.schemas.student_group_schema import (
    StudentGroupCreate,
    StudentGroupUpdate,
    StudentGroupOut,
    StudentGroupList,
)

router = APIRouter(prefix="/student-groups", tags=["Student Groups"])


@router.post("/", response_model=StudentGroupOut, status_code=201)
async def create_student_group(
    body: StudentGroupCreate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> StudentGroupOut:
    """Create a new student group."""
    # Check for duplicate code
    result = await db.execute(
        select(StudentGroup).where(
            StudentGroup.code == body.code,
            StudentGroup.deleted_at.is_(None),
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Student group with code '{body.code}' already exists",
        )

    student_group = StudentGroup(
        code=body.code,
        name=body.name,
        faculty=body.faculty,
        course_year=body.course_year,
        advisor_id=body.advisor_id,
    )
    db.add(student_group)
    await db.commit()
    await db.refresh(student_group)
    return StudentGroupOut.model_validate(student_group)


@router.get("/", response_model=StudentGroupList)
async def list_student_groups(
    code: Optional[str] = Query(None, description="Filter by code"),
    faculty: Optional[str] = Query(None, description="Filter by faculty"),
    course_year: Optional[str] = Query(None, description="Filter by course year"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> StudentGroupList:
    """List all student groups with optional filters."""
    query = select(StudentGroup).where(StudentGroup.deleted_at.is_(None))
    count_query = select(func.count(StudentGroup.id)).where(StudentGroup.deleted_at.is_(None))

    if code:
        query = query.where(StudentGroup.code.ilike(f"%{code}%"))
        count_query = count_query.where(StudentGroup.code.ilike(f"%{code}%"))
    if faculty:
        query = query.where(StudentGroup.faculty.ilike(f"%{faculty}%"))
        count_query = count_query.where(StudentGroup.faculty.ilike(f"%{faculty}%"))
    if course_year:
        query = query.where(StudentGroup.course_year == course_year)
        count_query = count_query.where(StudentGroup.course_year == course_year)

    query = query.order_by(StudentGroup.code).offset(skip).limit(limit)

    result = await db.execute(query)
    count_result = await db.execute(count_query)

    items = result.scalars().all()
    total = count_result.scalar_one()

    return StudentGroupList(total=total, items=[StudentGroupOut.model_validate(i) for i in items])


@router.get("/{group_id}", response_model=StudentGroupOut)
async def get_student_group(
    group_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> StudentGroupOut:
    """Get a specific student group by ID."""
    result = await db.execute(
        select(StudentGroup).where(
            StudentGroup.id == group_id,
            StudentGroup.deleted_at.is_(None),
        )
    )
    student_group = result.scalar_one_or_none()
    if not student_group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student group not found",
        )
    return StudentGroupOut.model_validate(student_group)


@router.patch("/{group_id}", response_model=StudentGroupOut)
async def update_student_group(
    group_id: uuid.UUID,
    body: StudentGroupUpdate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> StudentGroupOut:
    """Update a student group."""
    result = await db.execute(
        select(StudentGroup).where(
            StudentGroup.id == group_id,
            StudentGroup.deleted_at.is_(None),
        )
    )
    student_group = result.scalar_one_or_none()
    if not student_group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student group not found",
        )

    # Check for duplicate code if updating
    if body.code and body.code != student_group.code:
        existing = await db.execute(
            select(StudentGroup).where(
                StudentGroup.code == body.code,
                StudentGroup.id != group_id,
                StudentGroup.deleted_at.is_(None),
            )
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Student group with code '{body.code}' already exists",
            )

    # Update fields
    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(student_group, field, value)

    await db.commit()
    await db.refresh(student_group)
    return StudentGroupOut.model_validate(student_group)


@router.delete("/{group_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_student_group(
    group_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Soft delete a student group."""
    result = await db.execute(
        select(StudentGroup).where(
            StudentGroup.id == group_id,
            StudentGroup.deleted_at.is_(None),
        )
    )
    student_group = result.scalar_one_or_none()
    if not student_group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student group not found",
        )

    student_group.deleted_at = datetime.now(timezone.utc)
    await db.commit()
