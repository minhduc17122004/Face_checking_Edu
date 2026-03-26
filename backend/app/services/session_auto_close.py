from __future__ import annotations
"""Background job: auto-close expired sessions."""
import logging
from datetime import datetime, timezone

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.session import Session

logger = logging.getLogger(__name__)


async def auto_close_expired_sessions(db: AsyncSession) -> int:
    """Close all 'active' or 'paused' sessions whose end_time (or custom window) has passed.

    Returns the count of sessions that were closed.
    """
    now = datetime.now(timezone.utc)
    from app.models.course import Course
    from sqlalchemy import func
    
    # Subquery to find IDs of sessions that should be closed
    to_close_stmt = (
        select(Session.id)
        .where(
            Session.status.in_(["active", "paused"]),
            func.coalesce(Session.checkin_window_end, Session.end_time) <= now,
            Session.deleted_at.is_(None),
        )
    )
    result = await db.execute(to_close_stmt)
    ids = result.scalars().all()

    if not ids:
        return 0

    await db.execute(
        update(Session)
        .where(Session.id.in_(ids))
        .values(status="closed")
    )
    
    await db.commit()
    logger.info("Auto-closed %d expired sessions: %s", len(ids), ids)
    return len(ids)


async def auto_activate_scheduled_sessions(db: AsyncSession) -> int:
    """Activate all 'scheduled' sessions whose start_time (or custom window) has passed, 
    EXCEPT for flexible mode courses.

    Returns the count of sessions that were activated.
    """
    now = datetime.now(timezone.utc)
    from app.models.course import Course
    from sqlalchemy import func
    
    # Subquery: sessions that are scheduled, start_time passed, AND NOT flexible mode
    to_activate_stmt = (
        select(Session.id)
        .join(Course, Session.course_id == Course.id)
        .where(
            Session.status == "scheduled",
            func.coalesce(Session.checkin_window_start, Session.start_time) <= now,
            Session.deleted_at.is_(None),
            Course.attendance_mode != "flexible"
        )
    )
    result = await db.execute(to_activate_stmt)
    ids = result.scalars().all()

    if not ids:
        return 0

    await db.execute(
        update(Session)
        .where(Session.id.in_(ids))
        .values(status="active")
    )
    
    await db.commit()
    logger.info("Auto-activated %d scheduled sessions: %s", len(ids), ids)
    return len(ids)


async def run_session_maintenance(db: AsyncSession) -> tuple[int, int]:
    """Run full session maintenance: activate expired + close expired.

    Returns (activated_count, closed_count).
    """
    activated = await auto_activate_scheduled_sessions(db)
    closed = await auto_close_expired_sessions(db)
    return activated, closed
