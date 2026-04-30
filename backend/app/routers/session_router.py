from __future__ import annotations
"""Sessions router — actual attendance sessions."""
import uuid
from datetime import datetime, date, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.session import Session
from app.models.course import Course
from app.models.schedule import Schedule
from app.models.attendance import Attendance
from app.schemas.session_schema import (
    SessionCreate,
    SessionUpdate,
    SessionOut,
    SessionWithSchedule,
    SessionList,
    SessionSummary,
)

router = APIRouter(prefix="/sessions", tags=["Sessions"])


def _combine_datetime(session_date: date, time_value: datetime) -> datetime:
    """Combine session_date with time portion from time_value, preserving timezone."""
    if time_value.tzinfo:
        return time_value
    from datetime import time as dt_time
    return datetime.combine(session_date, dt_time(), tzinfo=timezone.utc)


@router.post("/", response_model=SessionOut, status_code=201)
async def create_session(
    body: SessionCreate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SessionOut:
    """Create a new attendance session."""
    result = await db.execute(
        select(Course).where(
            Course.id == body.course_id,
            Course.deleted_at.is_(None),
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found")

    if body.schedule_id:
        result = await db.execute(select(Schedule).where(Schedule.id == body.schedule_id))
        if not result.scalar_one_or_none():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Schedule not found")

    start_time = _combine_datetime(body.session_date, body.start_time)
    end_time = None
    if body.end_time:
        end_time = _combine_datetime(body.session_date, body.end_time)

    session = Session(
        course_id=body.course_id,
        schedule_id=body.schedule_id,
        session_date=body.session_date,
        start_time=start_time,
        end_time=end_time,
        checkin_window_start=body.checkin_window_start,
        checkin_window_end=body.checkin_window_end,
        status=body.status,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return SessionOut.model_validate(session)


@router.get("/", response_model=SessionList)
async def list_sessions(
    course_id: uuid.UUID | None = Query(None),
    session_date: date | None = Query(None),
    status_filter: str | None = Query(None, alias="status"),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SessionList:
    """List sessions with optional filters."""
    query = select(Session).where(Session.deleted_at.is_(None))
    count_query = select(func.count(Session.id)).where(Session.deleted_at.is_(None))

    if course_id:
        query = query.where(Session.course_id == course_id)
        count_query = count_query.where(Session.course_id == course_id)
    if session_date:
        query = query.where(Session.session_date == session_date)
        count_query = count_query.where(Session.session_date == session_date)
    if status_filter:
        query = query.where(Session.status == status_filter)
        count_query = count_query.where(Session.status == status_filter)

    query = query.options(selectinload(Session.schedule)).order_by(Session.start_time.desc())

    result = await db.execute(query)
    count_result = await db.execute(count_query)

    items = result.scalars().all()
    total = count_result.scalar_one()

    return SessionList(
        total=total,
        items=[SessionOut.model_validate(i) for i in items],
    )


@router.get("/{session_id}", response_model=SessionWithSchedule)
async def get_session(
    session_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SessionWithSchedule:
    """Get a specific session with schedule details."""
    result = await db.execute(
        select(Session)
        .options(selectinload(Session.schedule))
        .where(Session.id == session_id, Session.deleted_at.is_(None))
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    return SessionWithSchedule.model_validate(session)


@router.patch("/{session_id}", response_model=SessionOut)
async def update_session(
    session_id: uuid.UUID,
    body: SessionUpdate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SessionOut:
    """Update session status (e.g., close attendance)."""
    result = await db.execute(
        select(Session).where(Session.id == session_id, Session.deleted_at.is_(None))
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    session.status = body.status
    if body.end_time:
        session.end_time = body.end_time
    if body.checkin_window_start is not None:
        session.checkin_window_start = body.checkin_window_start
    if body.checkin_window_end is not None:
        session.checkin_window_end = body.checkin_window_end

    await db.commit()
    await db.refresh(session)
    return SessionOut.model_validate(session)


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session(
    session_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Soft delete a session."""
    result = await db.execute(
        select(Session).where(Session.id == session_id, Session.deleted_at.is_(None))
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    session.deleted_at = datetime.now(timezone.utc)
    await db.commit()


@router.get("/{session_id}/summary", response_model=SessionSummary)
async def get_session_summary(
    session_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SessionSummary:
    """Get attendance summary for a session."""
    result = await db.execute(
        select(Session).where(Session.id == session_id, Session.deleted_at.is_(None))
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    present_count = await db.execute(
        select(func.count(Attendance.id)).where(
            Attendance.session_id == session_id,
            Attendance.status == "present",
            Attendance.deleted_at.is_(None),
        )
    )
    late_count = await db.execute(
        select(func.count(Attendance.id)).where(
            Attendance.session_id == session_id,
            Attendance.status == "late",
            Attendance.deleted_at.is_(None),
        )
    )
    absent_count = await db.execute(
        select(func.count(Attendance.id)).where(
            Attendance.session_id == session_id,
            Attendance.status == "absent",
            Attendance.deleted_at.is_(None),
        )
    )

    total_students = (
        present_count.scalar_one() +
        late_count.scalar_one() +
        absent_count.scalar_one()
    )

    return SessionSummary(
        session=SessionOut.model_validate(session),
        total_students=total_students,
        present_count=present_count.scalar_one(),
        late_count=late_count.scalar_one(),
        absent_count=absent_count.scalar_one(),
    )
