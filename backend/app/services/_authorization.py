from __future__ import annotations
"""Authorization helpers — ownership and enrollment validation for v1 endpoints."""
import uuid

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.models.classroom import Classroom
from app.models.session import Session
from app.models.classroom_student import ClassroomStudent
from app.models.attendance import Attendance


def check_classroom_owner(classroom: Classroom, user_id: str) -> None:
    """Raise 403 if user is not the owner of the classroom."""
    if not classroom:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Classroom not found")
    if str(classroom.teacher_id) != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You do not own this classroom")


def check_session_owner(session: Session, user_id: str) -> None:
    """Raise 403 if user is not the owner of the session's classroom."""
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    if str(session.classroom.teacher_id) != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You do not own this session")


async def check_user_enrolled_in_classroom(
    db: AsyncSession,
    user_id: str,
    classroom_id: uuid.UUID,
) -> bool:
    """Check if a user is enrolled as a student in a classroom."""
    # First resolve user_id to student_id
    from app.models.student import Student
    result = await db.execute(
        select(Student.id).where(
            and_(
                Student.user_id == uuid.UUID(user_id),
                Student.is_deleted == False,  # noqa: E712
            )
        )
    )
    student_row = result.scalar_one_or_none()
    if not student_row:
        return False
    student_id = student_row

    # Check enrollment
    enrollment = await db.execute(
        select(ClassroomStudent).where(
            and_(
                ClassroomStudent.classroom_id == classroom_id,
                ClassroomStudent.student_id == student_id,
            )
        )
    )
    return enrollment.scalar_one_or_none() is not None


async def check_student_enrolled_in_session(
    db: AsyncSession,
    student_id: int,
    session_id: uuid.UUID,
) -> bool:
    """Check if a student is enrolled in the session's classroom."""
    # Get session to find classroom_id
    session = await db.execute(select(Session).where(Session.id == session_id))
    session = session.scalar_one_or_none()
    if not session:
        return False

    enrollment = await db.execute(
        select(ClassroomStudent).where(
            and_(
                ClassroomStudent.classroom_id == session.classroom_id,
                ClassroomStudent.student_id == student_id,
            )
        )
    )
    return enrollment.scalar_one_or_none() is not None
