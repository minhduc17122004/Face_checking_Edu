from __future__ import annotations
"""v1 CourseEnrollments router — /api/v1/course-enrollments endpoints."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.course_enrollment_repository import CourseEnrollmentRepository
from app.repositories.course_repository import CourseRepository
from app.repositories.student_repository import StudentRepository
from app.models.course_enrollment import CourseEnrollment
from app.schemas.v1.course_enrollment import (
    CourseEnrollmentCreate,
    CourseEnrollmentOut,
    CourseEnrollmentList,
)

router = APIRouter(prefix="/course-enrollments", tags=["v1 — CourseEnrollments"])


@router.post("/", response_model=CourseEnrollmentOut, status_code=status.HTTP_201_CREATED)
async def enroll_student(
    req: CourseEnrollmentCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Enroll a student in a course."""
    repo = CourseEnrollmentRepository(db)
    course_repo = CourseRepository(db)
    student_repo = StudentRepository(db)

    course = await course_repo.get_by_id(req.course_id)
    if not course or course.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Course not found.")

    student = await student_repo.get_by_id(req.student_id)
    if not student or student.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Student not found.")

    existing = await repo.find_enrollment(req.course_id, req.student_id)
    if existing:
        raise HTTPException(
            status_code=409,
            detail="Student already enrolled in this course.",
        )

    enrollment = CourseEnrollment(
        course_id=req.course_id,
        student_id=req.student_id,
    )
    db.add(enrollment)
    await db.flush()
    await db.refresh(enrollment)
    return CourseEnrollmentOut.model_validate(enrollment)


@router.get("/", response_model=CourseEnrollmentList)
async def list_enrollments(
    course_id: uuid.UUID | None = None,
    student_id: int | None = None,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List student enrollments with optional filters."""
    repo = CourseEnrollmentRepository(db)
    if course_id:
        items = await repo.get_by_course(course_id)
    elif student_id:
        items = await repo.get_by_student(student_id)
    else:
        items = []
    return CourseEnrollmentList(
        total=len(items),
        items=[CourseEnrollmentOut.model_validate(e) for e in items],
    )


@router.delete("/{enrollment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unenroll(
    enrollment_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Remove a student from a course."""
    repo = CourseEnrollmentRepository(db)
    enrollment = await repo.get_by_id(enrollment_id)
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found.")
    await db.delete(enrollment)
    await db.flush()
