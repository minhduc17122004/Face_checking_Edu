from __future__ import annotations
"""Classroom students router — many-to-many enrollment."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.classroom_student import ClassroomStudent
from app.models.classroom import Classroom
from app.models.student import Student
from app.schemas.classroom_student_schema import (
    ClassroomStudentCreate,
    ClassroomStudentOut,
    ClassroomStudentList,
)

router = APIRouter(prefix="/classroom-students", tags=["Classroom Students"])


@router.post("/", response_model=ClassroomStudentOut, status_code=201)
async def enroll_student(
    body: ClassroomStudentCreate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> ClassroomStudentOut:
    """Enroll a student in a classroom."""
    # Verify classroom exists
    result = await db.execute(select(Classroom).where(Classroom.id == body.classroom_id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Classroom not found")

    # Verify student exists
    result = await db.execute(select(Student).where(Student.id == body.student_id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    # Check for duplicate enrollment
    result = await db.execute(
        select(ClassroomStudent).where(
            ClassroomStudent.classroom_id == body.classroom_id,
            ClassroomStudent.student_id == body.student_id,
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Student already enrolled in this classroom",
        )

    enrollment = ClassroomStudent(
        classroom_id=body.classroom_id,
        student_id=body.student_id,
    )
    db.add(enrollment)
    await db.commit()
    await db.refresh(enrollment)
    return ClassroomStudentOut.model_validate(enrollment)


@router.get("/", response_model=ClassroomStudentList)
async def list_enrollments(
    classroom_id: uuid.UUID | None = Query(None),
    student_id: int | None = Query(None),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> ClassroomStudentList:
    """List classroom-student enrollments with optional filters."""
    query = select(ClassroomStudent)
    count_query = select(func.count(ClassroomStudent.id))

    if classroom_id:
        query = query.where(ClassroomStudent.classroom_id == classroom_id)
        count_query = count_query.where(ClassroomStudent.classroom_id == classroom_id)
    if student_id:
        query = query.where(ClassroomStudent.student_id == student_id)
        count_query = count_query.where(ClassroomStudent.student_id == student_id)

    result = await db.execute(query.order_by(ClassroomStudent.enrolled_at.desc()))
    count_result = await db.execute(count_query)

    items = result.scalars().all()
    total = count_result.scalar_one()
    return ClassroomStudentList(
        total=total,
        items=[ClassroomStudentOut.model_validate(i) for i in items],
    )


@router.delete("/{enrollment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unenroll_student(
    enrollment_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Remove a student from a classroom."""
    result = await db.execute(
        select(ClassroomStudent).where(ClassroomStudent.id == enrollment_id)
    )
    enrollment = result.scalar_one_or_none()
    if not enrollment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Enrollment not found")

    await db.delete(enrollment)
    await db.commit()
