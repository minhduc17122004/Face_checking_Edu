from __future__ import annotations
"""v1 ClassroomStudents router — /api/v1/classroom-students endpoints."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.classroom_student_repository import ClassroomStudentRepository
from app.repositories.classroom_repository import ClassroomRepository
from app.repositories.student_repository import StudentRepository
from app.models.classroom_student import ClassroomStudent
from app.schemas.v1.classroom_student import (
    ClassroomStudentCreate,
    ClassroomStudentOut,
    ClassroomStudentList,
)

router = APIRouter(prefix="/classroom-students", tags=["v1 — ClassroomStudents"])


@router.post("/", response_model=ClassroomStudentOut, status_code=status.HTTP_201_CREATED)
async def enroll_student(
    req: ClassroomStudentCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Enroll a student in a classroom."""
    repo = ClassroomStudentRepository(db)
    cls_repo = ClassroomRepository(db)
    st_repo = StudentRepository(db)

    classroom = await cls_repo.get_by_id(req.classroom_id)
    if not classroom or classroom.is_deleted:
        raise HTTPException(status_code=404, detail="Classroom not found.")

    student = await st_repo.get_by_id(req.student_id)
    if not student or student.is_deleted:
        raise HTTPException(status_code=404, detail="Student not found.")

    existing = await repo.find_enrollment(req.classroom_id, req.student_id)
    if existing:
        raise HTTPException(status_code=409, detail="Student already enrolled in this classroom.")

    enrollment = ClassroomStudent(
        classroom_id=req.classroom_id,
        student_id=req.student_id,
    )
    db.add(enrollment)
    await db.flush()
    await db.refresh(enrollment)
    return ClassroomStudentOut.model_validate(enrollment)


@router.get("/", response_model=ClassroomStudentList)
async def list_enrollments(
    classroom_id: uuid.UUID | None = None,
    student_id: int | None = None,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List student enrollments with optional filters."""
    repo = ClassroomStudentRepository(db)
    if classroom_id:
        items = await repo.get_by_classroom(classroom_id)
    elif student_id:
        items = await repo.get_by_student(student_id)
    else:
        items = []
    return ClassroomStudentList(total=len(items), items=[ClassroomStudentOut.model_validate(e) for e in items])


@router.delete("/{enrollment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unenroll(
    enrollment_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Remove a student from a classroom."""
    repo = ClassroomStudentRepository(db)
    enrollment = await repo.get_by_id(enrollment_id)
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found.")
    await db.delete(enrollment)
    await db.flush()
