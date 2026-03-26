from __future__ import annotations
"""v1 Room Sessions router — /api/v1/rooms/{id}/sessions endpoint (Phase 9)."""
import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.models.session import Session
from app.models.course import Course
from app.models.room import Room
from app.repositories.session_repository import SessionRepository
from app.repositories.attendance_repository import AttendanceRepository
from app.repositories.course_enrollment_repository import CourseEnrollmentRepository
from app.schemas.v1.room_session import RoomSessionResponse, RoomSessionList

router = APIRouter(prefix="/rooms", tags=["v1 — Room Sessions"])


async def _build_room_session_list(
    db: AsyncSession,
    sessions: list[Session],
) -> list[RoomSessionResponse]:
    """Build RoomSessionResponse list with attendance and enrollment counts."""
    from datetime import datetime, timezone, timedelta
    now = datetime.now(timezone.utc)
    results = []

    for session in sessions:
        course_name = session.course.course_name if session.course else "Unknown"

        # Count attendance for this session
        att_repo = AttendanceRepository(db)
        att_count = await att_repo.count_by_session(session.id)

        # Count enrolled students
        enroll_repo = CourseEnrollmentRepository(db)
        enrollments = await enroll_repo.get_by_course(session.course_id)
        enrolled_count = len(enrollments)

        # Determine effective status
        effective_status = session.status
        if session.status == "scheduled" and session.start_time and session.start_time <= now:
            effective_status = "active"
        elif session.status == "active" and session.end_time and session.end_time <= now:
            effective_status = "closed"

        # Phase 9: Compute can_checkin from time window
        can_checkin = False
        if session.attendance_mode != "flexible":
            early_min = 15
            late_min = 15
            if session.attendance_config:
                early_min = session.attendance_config.early_allowance
                late_min = session.attendance_config.late_allowance
            effective_start = session.start_time - timedelta(minutes=early_min)
            effective_end = session.end_time + timedelta(minutes=late_min) if session.end_time else None
            can_checkin = (
                effective_status == "active" and
                effective_start <= now <= (effective_end or datetime.max.replace(tzinfo=timezone.utc))
            )
        else:
            can_checkin = effective_status == "active"

        results.append(
            RoomSessionResponse(
                id=session.id,
                course_id=session.course_id,
                course_name=course_name,
                session_date=session.session_date,
                start_time=session.start_time,
                end_time=session.end_time,
                status=effective_status,
                attendance_count=att_count,
                total_enrolled=enrolled_count,
                can_checkin=can_checkin,
            )
        )
    return results


def _sort_sessions(sessions: list[RoomSessionResponse]) -> list[RoomSessionResponse]:
    """Sort: active first, then scheduled/upcoming, then closed."""
    def sort_key(s: RoomSessionResponse) -> tuple[int, int]:
        status_order = {"active": 0, "scheduled": 1, "closed": 2}
        return (status_order.get(s.status, 3), 0 if s.status == "active" else 1)

    return sorted(sessions, key=sort_key)


@router.get("/{room_id}/sessions", response_model=RoomSessionList)
async def get_room_sessions(
    room_id: uuid.UUID,
    session_date: date | None = Query(None, description="Filter by session date"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/rooms/{id}/sessions — get sessions for a room.

    Returns sessions for courses assigned to this room, sorted:
    1. Currently active sessions (status='active')
    2. Scheduled/upcoming sessions by start_time ASC
    3. Closed sessions last

    Includes attendance_count and total_enrolled for each session.
    """
    # Verify room exists
    room_result = await db.execute(select(Room).where(Room.id == room_id))
    room = room_result.scalar_one_or_none()
    if not room or room.deleted_at is not None:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Room not found")

    session_repo = SessionRepository(db)
    sessions, total = await session_repo.get_by_room_sorted(
        room_id=room_id,
        session_date=session_date,
        skip=skip,
        limit=limit,
    )

    items = await _build_room_session_list(db, list(sessions))
    sorted_items = _sort_sessions(items)

    return RoomSessionList(total=total, items=sorted_items)
