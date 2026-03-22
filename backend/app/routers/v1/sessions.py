from __future__ import annotations
"""v1 Sessions router — /api/v1/sessions endpoints."""
import uuid
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.session_repository import SessionRepository
from app.repositories.course_repository import CourseRepository
from app.services.attendance_service import AttendanceService
from app.services.session_generator_service import SessionGeneratorService
from app.services._authorization import check_course_owner, check_session_owner
from app.schemas.v1.session import (
    SessionCreate,
    SessionUpdate,
    SessionOut,
    SessionWithSchedule,
    SessionList,
)

router = APIRouter(prefix="/sessions", tags=["v1 — Sessions"])


def _session_out(s: any) -> SessionOut:
    return SessionOut(
        id=s.id,
        course_id=s.course_id,
        course_name=getattr(s.course, "course_name", None) if s.course_id else None,
        schedule_id=s.schedule_id,
        session_date=s.start_time.date() if s.start_time else None,
        start_time=s.start_time,
        end_time=s.end_time,
        checkin_window_start=s.checkin_window_start,
        checkin_window_end=s.checkin_window_end,
        status=s.status,
        created_at=s.created_at,
        updated_at=s.updated_at,
    )


@router.post("/", response_model=SessionOut, status_code=status.HTTP_201_CREATED)
async def create_session(
    req: SessionCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new attendance session."""
    repo = SessionRepository(db)
    course_repo = CourseRepository(db)

    course = await course_repo.get_by_id(req.course_id)
    if not course or not course.is_active:
        raise HTTPException(status_code=404, detail="Course not found.")
    check_course_owner(course, user_id)

    from datetime import datetime, timezone
    start = datetime.combine(req.session_date, datetime.min.time())
    end = None
    if req.end_time:
        end = datetime.combine(req.session_date, req.end_time.time()) if hasattr(req, "end_time") else req.end_time

    session = await repo.create(
        course_id=req.course_id,
        schedule_id=req.schedule_id,
        start_time=start,
        end_time=end or req.end_time,
        checkin_window_start=req.checkin_window_start,
        checkin_window_end=req.checkin_window_end,
        status=req.status,
    )
    await db.commit()
    return _session_out(session)


@router.get("/", response_model=SessionList)
async def list_sessions(
    course_id: uuid.UUID | None = None,
    session_date: date | None = None,
    status: str | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List sessions with optional filters."""
    repo = SessionRepository(db)
    items, total = await repo.list(
        course_id=course_id,
        session_date=session_date,
        status=status,
        skip=skip,
        limit=limit,
    )
    return SessionList(total=total, items=[_session_out(s) for s in items])


@router.get("/{session_id}", response_model=SessionOut)
async def get_session(
    session_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single session by ID."""
    repo = SessionRepository(db)
    session = await repo.get_by_id(session_id)
    if not session or session.is_deleted:
        raise HTTPException(status_code=404, detail="Session not found.")
    return _session_out(session)


@router.patch("/{session_id}", response_model=SessionOut)
async def update_session(
    session_id: uuid.UUID,
    req: SessionUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update session status (close attendance, etc.)."""
    repo = SessionRepository(db)
    session = await repo.get_by_id(session_id)
    check_session_owner(session, user_id)
    updated = await repo.update_status(
        session_id,
        status=req.status,
        end_time=req.end_time,
        checkin_window_start=req.checkin_window_start,
        checkin_window_end=req.checkin_window_end,
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Session not found.")
    await db.commit()
    return _session_out(updated)


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session(
    session_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete a session (owner only)."""
    repo = SessionRepository(db)
    session = await repo.get_by_id(session_id)
    check_session_owner(session, user_id)
    await repo.soft_delete(session)


@router.get("/{session_id}/summary")
async def session_summary(
    session_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get attendance summary for a session."""
    svc = AttendanceService(db)
    return await svc.get_session_summary(session_id)


@router.post("/generate-daily", status_code=status.HTTP_200_OK)
async def generate_daily_sessions(
    target_date: date | None = Query(None),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """POST /api/v1/sessions/generate-daily — auto-generate sessions from schedules.

    Generates attendance sessions for all active schedules on the given date.
    If no date is provided, generates for today.
    External cron jobs or schedulers call this endpoint daily.
    """
    from datetime import date as dt_date, datetime, timezone
    date_to_generate = target_date or datetime.now(timezone.utc).date()
    svc = SessionGeneratorService(db)
    sessions = await svc.generate_sessions_for_date(date_to_generate)
    return {"generated": len(sessions), "date": str(date_to_generate)}

