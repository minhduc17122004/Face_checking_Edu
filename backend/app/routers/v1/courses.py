from __future__ import annotations
"""v1 Courses router — /api/v1/courses endpoints."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.course_repository import CourseRepository
from app.repositories.course_enrollment_repository import CourseEnrollmentRepository
from app.services._authorization import check_course_owner
from app.schemas.v1.course import (
    CourseCreate,
    CourseOut,
    CourseList,
    CourseStudentDetail,
    CourseStudentListResponse,
)
from app.schemas.v1.common import PaginationParams

router = APIRouter(prefix="/courses", tags=["v1 — Courses"])


@router.post("/", response_model=CourseOut, status_code=status.HTTP_201_CREATED)
async def create_course(
    req: CourseCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new course."""
    repo = CourseRepository(db)
    course = await repo.create(
        course_name=req.course_name,
        instructor_id=uuid.UUID(user_id) if user_id else None,
        subject=req.subject,
        course_code=req.course_code,
    )
    await db.commit()
    return CourseOut.model_validate(course)


@router.get("/", response_model=CourseList)
async def list_courses(
    mine: bool = False,
    skip: int = 0,
    limit: int = 200,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all courses, optionally filtering by owner."""
    repo = CourseRepository(db)
    if mine:
        items = await repo.get_by_instructor(uuid.UUID(user_id))
        total = len(items)
    else:
        items = await repo.get_all(skip=skip, limit=limit)
        total = await repo.count()
    return CourseList(total=total, items=[CourseOut.model_validate(c) for c in items])


@router.get("/{course_id}", response_model=CourseOut)
async def get_course(
    course_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single course."""
    repo = CourseRepository(db)
    course = await repo.get_by_id(course_id)
    if not course or course.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Course not found.")
    return CourseOut.model_validate(course)


@router.get("/{course_id}/students", response_model=CourseStudentListResponse)
async def list_course_students(
    course_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all students enrolled in a course, with face registration status.

    Returns has_face (bool) and embedding_count (int) for each student.
    """
    repo = CourseRepository(db)
    course = await repo.get_by_id(course_id)
    if not course or course.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Course not found.")

    enrollment_repo = CourseEnrollmentRepository(db)
    rows = await enrollment_repo.get_students_with_face_status(course_id)

    students = [
        CourseStudentDetail(
            student_id=row.student_id,
            user_id=str(row.user_id) if row.user_id else None,
            pin=row.pin,
            has_face=row.has_face,
            embedding_count=row.embedding_count,
            enrolled_at=row.enrolled_at,
        )
        for row in rows
    ]
    return CourseStudentListResponse(
        course_id=course_id,
        total=len(students),
        students=students,
    )


@router.post("/{course_id}/students/{student_id}", status_code=status.HTTP_201_CREATED)
async def enroll_student(
    course_id: uuid.UUID,
    student_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Enroll a student in a course (owner only)."""
    repo = CourseRepository(db)
    course = await repo.get_by_id(course_id)
    check_course_owner(course, user_id)

    enrollment_repo = CourseEnrollmentRepository(db)

    # Duplicate check
    existing = await enrollment_repo.find_enrollment(course_id, student_id)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Student is already enrolled in this course.",
        )

    await enrollment_repo.create(
        course_id=course_id,
        student_id=student_id,
    )
    await db.commit()
    return {"message": "Student enrolled."}


@router.delete("/{course_id}/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unenroll_student(
    course_id: uuid.UUID,
    student_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Remove a student from a course (owner only)."""
    repo = CourseRepository(db)
    course = await repo.get_by_id(course_id)
    check_course_owner(course, user_id)

    enrollment_repo = CourseEnrollmentRepository(db)
    enrollment = await enrollment_repo.find_enrollment(course_id, student_id)
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found.")

    await enrollment_repo.delete(enrollment)
    await db.commit()


@router.delete("/{course_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_course(
    course_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Delete a course (owner only)."""
    repo = CourseRepository(db)
    course = await repo.get_by_id(course_id)
    check_course_owner(course, user_id)
    await repo.soft_delete(course)
    await db.commit()
