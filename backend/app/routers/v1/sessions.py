from __future__ import annotations
"""v1 Sessions router — thin layer, no business logic."""
import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.session_repository import SessionRepository
from app.repositories.course_repository import CourseRepository
from app.services.course_service import CourseService
from app.services.attendance_service import AttendanceService
from app.services.session_generator_service import SessionGeneratorService, VIETNAM_TZ
from app.services._authorization import check_course_owner, check_session_owner
from app.schemas.v1.session import (
    SessionCreate,
    SessionUpdate,
    SessionOut,
    SessionWithSchedule,
    SessionList,
)
from app.services.attendance_config_service import AttendanceConfigService
from app.models.user import User

router = APIRouter(prefix="/sessions", tags=["v1 — Sessions"])


async def _require_teacher_or_admin(db: AsyncSession, user_id: str) -> str:
    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user or user.role not in {"teacher", "admin"}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only teacher/admin can control session status.",
        )
    return user.role


def _map_session_status_for_ui(
    raw_status: str,
    can_open: bool,
) -> str:
    if raw_status == "closed":
        return "CLOSED"
    if raw_status == "active":
        return "OPEN"
    if raw_status == "paused":
        return "CAN_OPEN"
    if can_open:
        return "CAN_OPEN"
    return "NOT_OPEN"


def _session_out(s: any) -> SessionOut:
    return SessionOut(
        id=s.id,
        course_id=s.course_id,
        course_code=getattr(s.course, "course_code", None) if s.course_id else None,
        course_name=getattr(s.course, "course_name", None) if s.course_id else None,
        schedule_id=s.schedule_id,
        session_date=s.session_date,
        start_time=s.start_time,
        end_time=s.end_time,
        checkin_window_start=s.checkin_window_start,
        checkin_window_end=s.checkin_window_end,
        status=s.status,
        mode=getattr(s.course, "attendance_mode", None) if s.course_id else None,
        created_at=s.created_at,
        updated_at=s.updated_at,
        time_slot_name=getattr(s, "time_slot_name", None),
    )


def _extract_teacher_name(course: any) -> str | None:
    """Extract full name from course.teacher.user eager-loaded chain."""
    teacher = getattr(course, "teacher", None)
    if not teacher:
        return None
    user = getattr(teacher, "user", None)
    if not user:
        return None
    full_name = getattr(user, "full_name", None)
    if not full_name:
        first = getattr(user, "first_name", "") or ""
        last = getattr(user, "last_name", "") or ""
        full_name = f"{first} {last}".strip() or None
    return full_name


async def _get_enrolled_count_map(db: AsyncSession, course_ids: list) -> dict:
    """Batch fetch enrolled student counts for a list of course IDs."""
    if not course_ids:
        return {}
    from app.models.course_enrollment import CourseEnrollment
    from sqlalchemy import func as sa_func
    result = await db.execute(
        select(CourseEnrollment.course_id, sa_func.count().label("cnt"))
        .where(CourseEnrollment.course_id.in_(course_ids))
        .group_by(CourseEnrollment.course_id)
    )
    return {str(row.course_id): row.cnt for row in result.all()}


def _build_session_out(s: any, now, can_open: bool, can_close: bool, mode: str | None, enrolled_count: int = 0) -> SessionOut:
    """Build a fully-populated SessionOut from an eager-loaded Session ORM object."""
    course = s.course if s.course_id else None
    return SessionOut(
        id=s.id,
        course_id=s.course_id,
        course_code=getattr(course, "course_code", None),
        course_name=getattr(course, "course_name", None),
        teacher_name=_extract_teacher_name(course) if course else None,
        schedule_id=s.schedule_id,
        session_date=s.session_date,
        start_time=s.start_time,
        end_time=s.end_time,
        checkin_window_start=s.checkin_window_start,
        checkin_window_end=s.checkin_window_end,
        status=s.status,
        mode=mode,
        mapped_status=_compute_mapped_status(
            mode=mode,
            raw_status=s.status,
            start_time=s.start_time,
            end_time=s.end_time,
            checkin_window_start=s.checkin_window_start,
            checkin_window_end=s.checkin_window_end,
            can_open=can_open,
            now=now,
        ),
        can_open=can_open,
        can_close=can_close,
        created_at=s.created_at,
        updated_at=s.updated_at,
        room_name=s.room_name,
        day_of_week=s.day_of_week,
        time_slot_name=s.time_slot_name,
        enrolled_count=enrolled_count,
    )


async def _derive_session_ui_fields(
    db: AsyncSession, session: any
) -> dict:
    """Compute mapped_status, can_open, can_close for a session."""
    from app.services.attendance_config_service import AttendanceConfigService

    config_svc = AttendanceConfigService(db)
    mode = await config_svc.get_effective_mode(session.id)

    now = datetime.now(timezone.utc)
    is_in_window = session.start_time <= now and (
        session.end_time is None or now <= session.end_time
    )

    from app.repositories.session_repository import SessionRepository
    repo = SessionRepository(db)
    siblings = await repo.get_by_course(session.course_id, skip=0, limit=500)
    previous = [s for s in siblings if s.start_time < session.start_time]
    previous_closed = all(s.status == "closed" for s in previous)

    can_open = (
        mode == "flexible"
        and session.status in ("scheduled", "paused", "closed")
        and previous_closed
        and is_in_window
    )
    can_close = mode == "flexible" and session.status == "active"

    mapped_status = _map_session_status_for_ui(session.status, can_open)

    return {
        "mapped_status": mapped_status,
        "can_open": can_open,
        "can_close": can_close,
    }


# ── Thin helpers ────────────────────────────────────────────────────────────


def _get_current_teacher_id(db: AsyncSession, user_id: str) -> tuple[int | None, str]:
    """Return (teacher_id, user_id) tuple for service resolution."""
    return None, user_id


# ── Endpoints ───────────────────────────────────────────────────────────────


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

    # Service resolves ownership from user_id
    teacher_id = await CourseService.resolve_teacher_id_from_user(db, None, user_id)
    check_course_owner(course, teacher_id)

    from datetime import datetime, timezone
    start = datetime.combine(req.session_date, datetime.min.time())
    end = None
    if req.end_time:
        end = datetime.combine(req.session_date, req.end_time.time()) if hasattr(req, "end_time") else req.end_time

    session = await repo.create(
        course_id=req.course_id,
        schedule_id=req.schedule_id,
        session_date=req.session_date,
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


def _compute_mapped_status(
    mode: str | None,
    raw_status: str,
    start_time,
    end_time,
    checkin_window_start,
    checkin_window_end,
    can_open: bool,
    now,
) -> str:
    """Real-time mapped_status calculation based on mode and time windows.

    For preset/custom: derive state from clock time (not DB status).
    For flexible: rely on raw_status + can_open flag (manually controlled).
    """
    mode_lower = mode.lower() if mode else None

    # Universal check: if the main session window is completely over, it's CLOSED.
    # This prevents ANY session created past its execution time from showing up as "upcoming".
    if end_time and now > end_time:
        return "CLOSED"

    if mode_lower in ("preset", "custom"):
        if raw_status == "closed":
            return "CLOSED"

        win_start = checkin_window_start or start_time
        win_end   = checkin_window_end   or end_time

        # Within checkin window → OPEN
        if win_start and win_end and win_start <= now <= win_end:
            return "OPEN"

        # Checkin window passed (but overall end_time hasn't)
        # (Though we already checked now > end_time above, keeping logic discrete if win_end differs from end_time)
        if win_end and now > win_end:
            return "CLOSED"

        return "NOT_OPEN"

    # Flexible — manually controlled
    return _map_session_status_for_ui(raw_status, can_open)


@router.get("/admin", response_model=SessionList)
async def list_admin_sessions(
    session_date: date | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List ALL sessions for admin — supports session_date or date_from/date_to range."""
    from app.models.user import User
    from sqlalchemy import select

    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user or user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin only.")

    repo = SessionRepository(db)
    items, total = await repo.list_for_admin(
        session_date=session_date,
        date_from=date_from,
        date_to=date_to,
        skip=skip,
        limit=limit,
    )

    now = datetime.now(timezone.utc)
    course_ids = list({str(s.course_id) for s in items if s.course_id})
    enrolled_map = await _get_enrolled_count_map(db, [uuid.UUID(cid) for cid in course_ids])
    session_outs = []
    for s in items:
        mode = getattr(s.course, "attendance_mode", None) if s.course_id else None
        is_in_window = s.start_time <= now and (s.end_time is None or now <= s.end_time)
        siblings = await repo.get_by_course(s.course_id, skip=0, limit=500)
        previous_closed = all(x.status == "closed" for x in siblings if x.start_time < s.start_time)
        can_open = mode == "flexible" and s.status in ("scheduled", "paused", "closed") and previous_closed and is_in_window
        can_close = mode == "flexible" and s.status == "active"
        enrolled = enrolled_map.get(str(s.course_id), 0)
        session_outs.append(_build_session_out(s, now, can_open, can_close, mode, enrolled_count=enrolled))

    return SessionList(total=total, items=session_outs)


@router.get("/teacher", response_model=SessionList)
async def list_teacher_sessions(
    session_date: date | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all sessions for courses where the current user is the teacher."""
    from app.services.course_service import CourseService
    from app.models.user import User
    from sqlalchemy import select
    
    # Get user role
    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    is_admin = user and user.role == "admin"

    repo = SessionRepository(db)

    if is_admin:
        items, total = await repo.list(
            session_date=session_date,
            skip=skip,
            limit=limit,
        )
    else:
        teacher_id = await CourseService.resolve_teacher_id_from_user(db, None, user_id, required=False)
        if not teacher_id:
            return SessionList(total=0, items=[])

        items, total = await repo.get_sessions_by_teacher(
            teacher_id=teacher_id,
            session_date=session_date,
            date_from=date_from,
            date_to=date_to,
            skip=skip,
            limit=limit,
        )

    now = datetime.now(timezone.utc)
    course_ids = list({str(s.course_id) for s in items if s.course_id})
    enrolled_map = await _get_enrolled_count_map(db, [uuid.UUID(cid) for cid in course_ids])
    session_outs = []

    for s in items:
        mode = getattr(s.course, "attendance_mode", None) if s.course_id else None
        is_in_window = s.start_time <= now and (s.end_time is None or now <= s.end_time)
        siblings = await repo.get_by_course(s.course_id, skip=0, limit=500)
        previous_closed = all(x.status == "closed" for x in siblings if x.start_time < s.start_time)
        can_open = mode == "flexible" and s.status in ("scheduled", "paused", "closed") and previous_closed and is_in_window
        can_close = mode == "flexible" and s.status == "active"
        enrolled = enrolled_map.get(str(s.course_id), 0)
        session_outs.append(_build_session_out(s, now, can_open, can_close, mode, enrolled_count=enrolled))

    return SessionList(total=total, items=session_outs)


@router.get("/teacher/active-or-next")
async def get_teacher_active_or_next_session(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Return the most relevant session for the current teacher."""
    svc = AttendanceService(db)
    config_svc = AttendanceConfigService(db)
    session = await svc.get_active_or_next_session_for_teacher(uuid.UUID(user_id))

    if not session:
        return {"session": None}

    mode = await config_svc.get_effective_mode(session.id)

    # Derived status logic
    now = datetime.now(timezone.utc)
    is_in_window = session.start_time <= now and (
        session.end_time is None or now <= session.end_time
    )

    repo = SessionRepository(db)
    siblings = await repo.get_by_course(session.course_id, skip=0, limit=100)
    previous = [s for s in siblings if s.start_time < session.start_time]
    previous_closed = all(s.status == "closed" for s in previous)

    can_open = mode == "FLEXIBLE" and session.status != "closed" and previous_closed and is_in_window
    can_close = mode == "FLEXIBLE" and session.status == "active"

    status_label = _map_session_status_for_ui(session.status, can_open)

    return {
        "session": _session_out(session),
        "status": status_label,
        "mode": mode,
        "can_open": can_open,
        "can_close": can_close,
    }


@router.get("/{session_id}", response_model=SessionOut)
async def get_session(
    session_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single session by ID."""
    repo = SessionRepository(db)

    # Needs to properly fetch the session with relationships to correctly derive UI fields and room
    from sqlalchemy.orm import selectinload
    from app.models.course import Course
    from app.models.session import Session
    from app.models.schedule import Schedule

    result = await db.execute(
        select(Session)
        .options(
            selectinload(Session.course).selectinload(Course.room),
            selectinload(Session.schedule).selectinload(Schedule.time_slot),
            selectinload(Session.schedule).selectinload(Schedule.end_time_slot),
        )
        .where(Session.id == session_id)
    )
    session = result.scalar_one_or_none()

    if not session or session.is_deleted:
        raise HTTPException(status_code=404, detail="Session not found.")

    ui_fields = await _derive_session_ui_fields(db, session)
    out = _session_out(session)
    out.mapped_status = ui_fields["mapped_status"]
    out.can_open = ui_fields["can_open"]
    out.can_close = ui_fields["can_close"]

    if session.course and session.course.room:
        out.room_name = session.course.room.name
    out.day_of_week = session.day_of_week
    return out


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

    # Service resolves ownership from user_id
    teacher_id = await CourseService.resolve_teacher_id_from_user(db, None, user_id)
    check_session_owner(session, teacher_id)

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


@router.get("/{session_id}/status")
async def get_session_status(
    session_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Return mapped status view: NOT_OPEN/CAN_OPEN/OPEN/CLOSED."""
    await _require_teacher_or_admin(db, user_id)
    repo = SessionRepository(db)
    config_svc = AttendanceConfigService(db)
    session = await repo.get_by_id(session_id)
    if not session or session.is_deleted:
        raise HTTPException(status_code=404, detail="Session not found.")

    mode = await config_svc.get_effective_mode(session.id)
    now = datetime.now(timezone.utc)
    is_in_window = session.start_time <= now and (
        session.end_time is None or now <= session.end_time
    )

    siblings = await repo.get_by_course(session.course_id, skip=0, limit=100)
    previous = [s for s in siblings if s.start_time < session.start_time]
    previous_closed = all(s.status == "closed" for s in previous)

    can_open = mode == "FLEXIBLE" and session.status != "closed" and previous_closed and is_in_window
    can_close = mode == "FLEXIBLE" and session.status == "active"

    return {
        "session_id": str(session.id),
        "status": _map_session_status_for_ui(session.status, can_open),
        "mode": mode,
        "raw_status": session.status,
        "can_open": can_open,
        "can_close": can_close,
    }


@router.post("/{session_id}/open")
async def open_session(
    session_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Open a session when previous sessions are closed and time window is valid."""
    await _require_teacher_or_admin(db, user_id)
    repo = SessionRepository(db)
    config_svc = AttendanceConfigService(db)
    session = await repo.get_by_id(session_id)
    if not session or session.is_deleted:
        raise HTTPException(status_code=404, detail="Session not found.")

    mode = await config_svc.get_effective_mode(session.id)
    if mode != "FLEXIBLE":
        raise HTTPException(
            status_code=400, detail="Only FLEXIBLE sessions can be opened manually."
        )

    # Removed limitation: Flexible sessions can be opened even if currently closed
    if session.status == "active":
        raise HTTPException(status_code=400, detail="Session is already open.")

    now = datetime.now(timezone.utc)
    if now < session.start_time:
        raise HTTPException(status_code=400, detail="Session not started yet.")
    if session.end_time and now > session.end_time:
        raise HTTPException(status_code=400, detail="Session time window has expired.")

    siblings = await repo.get_by_course(session.course_id, skip=0, limit=500)
    previous = [s for s in siblings if s.start_time < session.start_time]

    for prev in previous:
        if prev.status != "closed":
            if prev.end_time and prev.end_time < now:
                prev.status = "closed"
            else:
                raise HTTPException(
                    status_code=400,
                    detail=f"Previous session {prev.id} is still active and hasn't reached its end time.",
                )

    session.status = "active"
    # Restore end_time from schedule if it was cleared by a previous manual close
    if session.end_time is None and session.schedule_id:
        schedule = session.schedule
        if schedule and schedule.time_slot:
            end_slot = schedule.end_time_slot or schedule.time_slot
            session.end_time = datetime.combine(
                session.start_time.date(), end_slot.end_time
            ).replace(tzinfo=session.start_time.tzinfo or timezone.utc)
    await db.commit()
    await db.refresh(session)
    return {"session_id": str(session.id), "status": "OPEN"}


@router.post("/{session_id}/close")
async def close_session(
    session_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Close an active session."""
    await _require_teacher_or_admin(db, user_id)
    repo = SessionRepository(db)
    config_svc = AttendanceConfigService(db)
    session = await repo.get_by_id(session_id)
    if not session or session.is_deleted:
        raise HTTPException(status_code=404, detail="Session not found.")

    mode = await config_svc.get_effective_mode(session.id)
    if mode != "FLEXIBLE":
        raise HTTPException(
            status_code=400, detail="Only FLEXIBLE sessions can be closed manually."
        )

    if session.status != "active":
        raise HTTPException(
            status_code=400,
            detail="Only OPEN sessions can be closed.",
        )

    now = datetime.now(timezone.utc)
    # Check if the session's time window has expired → permanently close
    if session.end_time and now >= session.end_time:
        session.status = "closed"
        return_status = "CLOSED"
    else:
        # For flexible, teacher manually closed. Mark as closed so it appears in "Đã đóng" tab.
        # They can still reopen it if the window hasn't expired.
        session.status = "closed"
        return_status = "CLOSED"

    await db.commit()
    await db.refresh(session)
    return {"session_id": str(session.id), "status": return_status}


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session(
    session_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete a session (owner only)."""
    repo = SessionRepository(db)
    session = await repo.get_by_id(session_id)

    # Service resolves ownership from user_id
    teacher_id = await CourseService.resolve_teacher_id_from_user(db, None, user_id)
    check_session_owner(session, teacher_id)

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
    date_to_generate = target_date or datetime.now(VIETNAM_TZ).date()
    svc = SessionGeneratorService(db)
    sessions = await svc.generate_sessions_for_date(date_to_generate)
    return {"generated": len(sessions), "date": str(date_to_generate)}
