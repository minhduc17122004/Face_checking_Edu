from __future__ import annotations
"""v1 Classrooms router — /api/v1/classrooms endpoints."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.classroom_repository import ClassroomRepository
from app.repositories.classroom_student_repository import ClassroomStudentRepository
from app.services._authorization import check_classroom_owner
from app.schemas.v1.classroom import (
    ClassCreate,
    ClassOut,
    ClassList,
    ClassroomStudentDetail,
    ClassroomStudentListResponse,
)
from app.schemas.v1.common import PaginationParams

router = APIRouter(prefix="/classrooms", tags=["v1 — Classrooms"])


@router.post("/", response_model=ClassOut, status_code=status.HTTP_201_CREATED)
async def create_classroom(
    req: ClassCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new classroom."""
    repo = ClassroomRepository(db)
    classroom = await repo.create(
        class_name=req.class_name,
        teacher_id=uuid.UUID(user_id) if user_id else None,
        subject=req.subject,
    )
    await db.commit()
    return ClassOut.model_validate(classroom)


@router.get("/", response_model=ClassList)
async def list_classrooms(
    mine: bool = False,
    skip: int = 0,
    limit: int = 200,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all classrooms, optionally filtering by owner."""
    repo = ClassroomRepository(db)
    if mine:
        items = await repo.get_by_teacher(uuid.UUID(user_id))
        total = len(items)
    else:
        items = await repo.get_all(skip=skip, limit=limit)
        total = await repo.count()
    return ClassList(total=total, items=[ClassOut.model_validate(c) for c in items])


@router.get("/{classroom_id}", response_model=ClassOut)
async def get_classroom(
    classroom_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single classroom."""
    repo = ClassroomRepository(db)
    classroom = await repo.get_by_id(classroom_id)
    if not classroom or classroom.is_deleted:
        raise HTTPException(status_code=404, detail="Classroom not found.")
    return ClassOut.model_validate(classroom)


@router.get("/{classroom_id}/students", response_model=ClassroomStudentListResponse)
async def list_classroom_students(
    classroom_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all students enrolled in a classroom, with face registration status.

    Returns has_face (bool) and embedding_count (int) for each student.
    """
    repo = ClassroomRepository(db)
    classroom = await repo.get_by_id(classroom_id)
    if not classroom or classroom.is_deleted:
        raise HTTPException(status_code=404, detail="Classroom not found.")

    cs_repo = ClassroomStudentRepository(db)
    rows = await cs_repo.get_students_with_face_status(classroom_id)

    students = [
        ClassroomStudentDetail(
            student_id=row.student_id,
            name=row.name,
            pin=row.pin,
            has_face=row.has_face,
            embedding_count=row.embedding_count,
            enrolled_at=row.enrolled_at,
        )
        for row in rows
    ]
    return ClassroomStudentListResponse(
        classroom_id=classroom_id,
        total=len(students),
        students=students,
    )


@router.post("/{classroom_id}/students/{student_id}", status_code=status.HTTP_201_CREATED)
async def enroll_student(
    classroom_id: uuid.UUID,
    student_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Enroll a student in a classroom (owner only)."""
    repo = ClassroomRepository(db)
    classroom = await repo.get_by_id(classroom_id)
    check_classroom_owner(classroom, user_id)

    cs_repo = ClassroomStudentRepository(db)

    # Duplicate check
    existing = await cs_repo.find_enrollment(classroom_id, student_id)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Student is already enrolled in this classroom.",
        )

    await cs_repo.create(
        classroom_id=classroom_id,
        student_id=student_id,
    )
    await db.commit()
    return {"message": "Student enrolled."}


@router.delete("/{classroom_id}/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unenroll_student(
    classroom_id: uuid.UUID,
    student_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Remove a student from a classroom (owner only)."""
    repo = ClassroomRepository(db)
    classroom = await repo.get_by_id(classroom_id)
    check_classroom_owner(classroom, user_id)

    cs_repo = ClassroomStudentRepository(db)
    enrollment = await cs_repo.find_enrollment(classroom_id, student_id)
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found.")

    await cs_repo.soft_delete(enrollment)


@router.delete("/{classroom_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_classroom(
    classroom_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Delete a classroom (owner only)."""
    repo = ClassroomRepository(db)
    classroom = await repo.get_by_id(classroom_id)
    check_classroom_owner(classroom, user_id)
    await repo.delete(classroom)
