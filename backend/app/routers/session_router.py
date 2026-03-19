from __future__ import annotations
"""Sessions router — actual attendance sessions."""
import uuid
from datetime import datetime, date, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, cast, Date
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.session import Session
from app.models.classroom import Classroom
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
    # Verify classroom exists
    result = await db.execute(
        select(Classroom).where(
            Classroom.id == body.classroom_id,
            Classroom.is_deleted == False,
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Classroom not found")

    # Verify schedule if provided
    if body.schedule_id:
        result = await db.execute(select(Schedule).where(Schedule.id == body.schedule_id))
        if not result.scalar_one_or_none():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Schedule not found")

    # Combine session_date with start_time (TIMESTAMP now)
    start_time = _combine_datetime(body.session_date, body.start_time)
    end_time = None
    if body.end_time:
        end_time = _combine_datetime(body.session_date, body.end_time)

    session = Session(
        classroom_id=body.classroom_id,
        schedule_id=body.schedule_id,
        start_time=start_time,
        end_time=end_time,
        checkin_start_time=body.checkin_start_time,
        checkin_end_time=body.checkin_end_time,
        status=body.status,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return SessionOut.model_validate(session)


@router.get("/", response_model=SessionList)
async def list_sessions(
    classroom_id: uuid.UUID | None = Query(None),
    session_date: date | None = Query(None),
    status_filter: str | None = Query(None, alias="status"),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SessionList:
    """List sessions with optional filters."""
    query = select(Session).where(Session.is_deleted == False)
    count_query = select(func.count(Session.id)).where(Session.is_deleted == False)

    if classroom_id:
        query = query.where(Session.classroom_id == classroom_id)
        count_query = count_query.where(Session.classroom_id == classroom_id)
    if session_date:
        # Filter by date portion of start_time
        query = query.where(cast(Session.start_time, Date) == session_date)
        count_query = count_query.where(cast(Session.start_time, Date) == session_date)
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
        .where(Session.id == session_id, Session.is_deleted == False)
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
        select(Session).where(Session.id == session_id, Session.is_deleted == False)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    session.status = body.status
    if body.end_time:
        session.end_time = body.end_time
    if body.checkin_start_time is not None:
        session.checkin_start_time = body.checkin_start_time
    if body.checkin_end_time is not None:
        session.checkin_end_time = body.checkin_end_time

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
        select(Session).where(Session.id == session_id, Session.is_deleted == False)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    session.is_deleted = True
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
        select(Session).where(Session.id == session_id, Session.is_deleted == False)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    # Count attendance by status (only non-deleted)
    present_count = await db.execute(
        select(func.count(Attendance.id)).where(
            Attendance.session_id == session_id,
            Attendance.status == "present",
            Attendance.is_deleted == False,
        )
    )
    late_count = await db.execute(
        select(func.count(Attendance.id)).where(
            Attendance.session_id == session_id,
            Attendance.status == "late",
            Attendance.is_deleted == False,
        )
    )
    absent_count = await db.execute(
        select(func.count(Attendance.id)).where(
            Attendance.session_id == session_id,
            Attendance.status == "absent",
            Attendance.is_deleted == False,
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
