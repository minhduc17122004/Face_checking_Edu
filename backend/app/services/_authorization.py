from __future__ import annotations
"""Authorization helpers — ownership and enrollment validation for v1 endpoints."""
import uuid

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.models.course import Course
from app.models.session import Session
from app.models.course_enrollment import CourseEnrollment
from app.models.attendance import Attendance


def check_course_owner(course: Course, user_id: str) -> None:
    """Raise 403 if user is not the owner of the course."""
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )
    if str(course.instructor_id) != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not own this course",
        )


def check_session_owner(session: Session, user_id: str) -> None:
    """Raise 403 if user is not the owner of the session's course."""
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )
    if str(session.course.instructor_id) != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not own this session",
        )


async def check_user_enrolled_in_course(
    db: AsyncSession,
    user_id: str,
    course_id: uuid.UUID,
) -> bool:
    """Check if a user is enrolled as a student in a course."""
    # First resolve user_id to student_id
    from app.models.student import Student
    result = await db.execute(
        select(Student.id).where(
            and_(
                Student.user_id == uuid.UUID(user_id),
                Student.deleted_at.is_(None),
            )
        )
    )
    student_row = result.scalar_one_or_none()
    if not student_row:
        return False
    student_id = student_row

    # Check enrollment
    enrollment = await db.execute(
        select(CourseEnrollment).where(
            and_(
                CourseEnrollment.course_id == course_id,
                CourseEnrollment.student_id == student_id,
            )
        )
    )
    return enrollment.scalar_one_or_none() is not None


async def check_student_enrolled_in_session(
    db: AsyncSession,
    student_id: int,
    session_id: uuid.UUID,
) -> bool:
    """Check if a student is enrolled in the session's course."""
    # Get session to find course_id
    session = await db.execute(select(Session).where(Session.id == session_id))
    session = session.scalar_one_or_none()
    if not session:
        return False

    enrollment = await db.execute(
        select(CourseEnrollment).where(
            and_(
                CourseEnrollment.course_id == session.course_id,
                CourseEnrollment.student_id == student_id,
            )
        )
    )
    return enrollment.scalar_one_or_none() is not None
