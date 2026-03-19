from __future__ import annotations
"""Academic classes router — administrative class management."""
import uuid
from typing import Optional
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.academic_class import AcademicClass
from app.schemas.academic_class_schema import (
    AcademicClassCreate,
    AcademicClassUpdate,
    AcademicClassOut,
    AcademicClassList,
)

router = APIRouter(prefix="/academic-classes", tags=["Academic Classes"])


@router.post("/", response_model=AcademicClassOut, status_code=201)
async def create_academic_class(
    body: AcademicClassCreate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AcademicClassOut:
    """Create a new academic class."""
    # Check for duplicate code
    result = await db.execute(
        select(AcademicClass).where(
            AcademicClass.code == body.code,
            AcademicClass.is_deleted == False,
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Academic class with code '{body.code}' already exists",
        )

    academic_class = AcademicClass(
        code=body.code,
        name=body.name,
        faculty=body.faculty,
        course_year=body.course_year,
        advisor_id=body.advisor_id,
    )
    db.add(academic_class)
    await db.commit()
    await db.refresh(academic_class)
    return AcademicClassOut.model_validate(academic_class)


@router.get("/", response_model=AcademicClassList)
async def list_academic_classes(
    code: Optional[str] = Query(None, description="Filter by code"),
    faculty: Optional[str] = Query(None, description="Filter by faculty"),
    course_year: Optional[str] = Query(None, description="Filter by course year"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AcademicClassList:
    """List all academic classes with optional filters."""
    query = select(AcademicClass).where(AcademicClass.is_deleted == False)
    count_query = select(func.count(AcademicClass.id)).where(AcademicClass.is_deleted == False)

    if code:
        query = query.where(AcademicClass.code.ilike(f"%{code}%"))
        count_query = count_query.where(AcademicClass.code.ilike(f"%{code}%"))
    if faculty:
        query = query.where(AcademicClass.faculty.ilike(f"%{faculty}%"))
        count_query = count_query.where(AcademicClass.faculty.ilike(f"%{faculty}%"))
    if course_year:
        query = query.where(AcademicClass.course_year == course_year)
        count_query = count_query.where(AcademicClass.course_year == course_year)

    query = query.order_by(AcademicClass.code).offset(skip).limit(limit)

    result = await db.execute(query)
    count_result = await db.execute(count_query)

    items = result.scalars().all()
    total = count_result.scalar_one()

    return AcademicClassList(total=total, items=[AcademicClassOut.model_validate(i) for i in items])


@router.get("/{class_id}", response_model=AcademicClassOut)
async def get_academic_class(
    class_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AcademicClassOut:
    """Get a specific academic class by ID."""
    result = await db.execute(
        select(AcademicClass).where(
            AcademicClass.id == class_id,
            AcademicClass.is_deleted == False,
        )
    )
    academic_class = result.scalar_one_or_none()
    if not academic_class:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Academic class not found",
        )
    return AcademicClassOut.model_validate(academic_class)


@router.patch("/{class_id}", response_model=AcademicClassOut)
async def update_academic_class(
    class_id: uuid.UUID,
    body: AcademicClassUpdate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AcademicClassOut:
    """Update an academic class."""
    result = await db.execute(
        select(AcademicClass).where(
            AcademicClass.id == class_id,
            AcademicClass.is_deleted == False,
        )
    )
    academic_class = result.scalar_one_or_none()
    if not academic_class:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Academic class not found",
        )

    # Check for duplicate code if updating
    if body.code and body.code != academic_class.code:
        existing = await db.execute(
            select(AcademicClass).where(
                AcademicClass.code == body.code,
                AcademicClass.id != class_id,
                AcademicClass.is_deleted == False,
            )
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Academic class with code '{body.code}' already exists",
            )

    # Update fields
    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(academic_class, field, value)

    await db.commit()
    await db.refresh(academic_class)
    return AcademicClassOut.model_validate(academic_class)


@router.delete("/{class_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_academic_class(
    class_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Soft delete an academic class."""
    result = await db.execute(
        select(AcademicClass).where(
            AcademicClass.id == class_id,
            AcademicClass.is_deleted == False,
        )
    )
    academic_class = result.scalar_one_or_none()
    if not academic_class:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Academic class not found",
        )

    academic_class.is_deleted = True
    academic_class.deleted_at = datetime.now(timezone.utc)
    await db.commit()
