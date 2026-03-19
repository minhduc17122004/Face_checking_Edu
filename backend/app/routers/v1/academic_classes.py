from __future__ import annotations
"""v1 AcademicClasses router — /api/v1/academic-classes endpoints."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.academic_class_repository import AcademicClassRepository
from app.models.academic_class import AcademicClass
from app.schemas.v1.academic_class import (
    AcademicClassCreate,
    AcademicClassUpdate,
    AcademicClassOut,
    AcademicClassList,
)

router = APIRouter(prefix="/academic-classes", tags=["v1 — AcademicClasses"])


@router.post("/", response_model=AcademicClassOut, status_code=status.HTTP_201_CREATED)
async def create_academic_class(
    req: AcademicClassCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new academic class."""
    repo = AcademicClassRepository(db)
    existing = await repo.get_by_code(req.code)
    if existing and not existing.is_deleted:
        raise HTTPException(status_code=409, detail=f"Academic class with code '{req.code}' already exists.")

    cls = AcademicClass(
        code=req.code,
        name=req.name,
        faculty=req.faculty,
        course_year=req.course_year,
        advisor_id=req.advisor_id,
    )
    db.add(cls)
    await db.flush()
    await db.refresh(cls)
    return AcademicClassOut.model_validate(cls)


@router.get("/", response_model=AcademicClassList)
async def list_academic_classes(
    code: str | None = None,
    faculty: str | None = None,
    course_year: str | None = None,
    skip: int = 0,
    limit: int = 200,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List academic classes with optional filters."""
    repo = AcademicClassRepository(db)
    items, total = await repo.list(
        code=code,
        faculty=faculty,
        course_year=course_year,
        skip=skip,
        limit=limit,
    )
    return AcademicClassList(total=total, items=[AcademicClassOut.model_validate(c) for c in items])


@router.get("/{class_id}", response_model=AcademicClassOut)
async def get_academic_class(
    class_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single academic class."""
    repo = AcademicClassRepository(db)
    cls = await repo.get_by_id(class_id)
    if not cls or cls.is_deleted:
        raise HTTPException(status_code=404, detail="Academic class not found.")
    return AcademicClassOut.model_validate(cls)


@router.patch("/{class_id}", response_model=AcademicClassOut)
async def update_academic_class(
    class_id: uuid.UUID,
    req: AcademicClassUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update an academic class."""
    repo = AcademicClassRepository(db)
    cls = await repo.get_by_id(class_id)
    if not cls or cls.is_deleted:
        raise HTTPException(status_code=404, detail="Academic class not found.")

    if req.code is not None:
        other = await repo.get_by_code(req.code)
        if other and other.id != class_id and not other.is_deleted:
            raise HTTPException(status_code=409, detail="Code already in use.")
        cls.code = req.code
    if req.name is not None:
        cls.name = req.name
    if req.faculty is not None:
        cls.faculty = req.faculty
    if req.course_year is not None:
        cls.course_year = req.course_year
    if req.advisor_id is not None:
        cls.advisor_id = req.advisor_id

    await db.flush()
    await db.refresh(cls)
    return AcademicClassOut.model_validate(cls)


@router.delete("/{class_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_academic_class(
    class_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete an academic class."""
    repo = AcademicClassRepository(db)
    cls = await repo.get_by_id(class_id)
    if not cls:
        raise HTTPException(status_code=404, detail="Academic class not found.")
    await repo.soft_delete(cls)
