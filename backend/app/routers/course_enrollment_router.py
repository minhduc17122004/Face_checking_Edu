from __future__ import annotations
"""Course enrollment router — many-to-many enrollment."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.course_enrollment import CourseEnrollment
from app.models.course import Course
from app.models.student import Student
from app.schemas.course_enrollment_schema import (
    CourseEnrollmentCreate,
    CourseEnrollmentOut,
    CourseEnrollmentList,
)

router = APIRouter(prefix="/course-enrollments", tags=["Course Enrollments"])


@router.post("/", response_model=CourseEnrollmentOut, status_code=201)
async def enroll_student(
    body: CourseEnrollmentCreate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> CourseEnrollmentOut:
    """Enroll a student in a course."""
    # Verify course exists
    result = await db.execute(select(Course).where(Course.id == body.course_id))
    if not result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )

    # Verify student exists
    result = await db.execute(select(Student).where(Student.id == body.student_id))
    if not result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found",
        )

    # Check for duplicate enrollment
    result = await db.execute(
        select(CourseEnrollment).where(
            CourseEnrollment.course_id == body.course_id,
            CourseEnrollment.student_id == body.student_id,
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Student already enrolled in this course",
        )

    enrollment = CourseEnrollment(
        course_id=body.course_id,
        student_id=body.student_id,
    )
    db.add(enrollment)
    await db.commit()
    await db.refresh(enrollment)
    return CourseEnrollmentOut.model_validate(enrollment)


@router.get("/", response_model=CourseEnrollmentList)
async def list_enrollments(
    course_id: uuid.UUID | None = Query(None),
    student_id: int | None = Query(None),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> CourseEnrollmentList:
    """List course-student enrollments with optional filters."""
    query = select(CourseEnrollment)
    count_query = select(func.count(CourseEnrollment.id))

    if course_id:
        query = query.where(CourseEnrollment.course_id == course_id)
        count_query = count_query.where(CourseEnrollment.course_id == course_id)
    if student_id:
        query = query.where(CourseEnrollment.student_id == student_id)
        count_query = count_query.where(CourseEnrollment.student_id == student_id)

    result = await db.execute(query.order_by(CourseEnrollment.enrolled_at.desc()))
    count_result = await db.execute(count_query)

    items = result.scalars().all()
    total = count_result.scalar_one()
    return CourseEnrollmentList(
        total=total,
        items=[CourseEnrollmentOut.model_validate(i) for i in items],
    )


@router.delete("/{enrollment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unenroll_student(
    enrollment_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Remove a student from a course."""
    result = await db.execute(
        select(CourseEnrollment).where(CourseEnrollment.id == enrollment_id)
    )
    enrollment = result.scalar_one_or_none()
    if not enrollment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Enrollment not found",
        )

    await db.delete(enrollment)
    await db.commit()
