from __future__ import annotations
"""Background job: auto-close expired sessions."""
import logging
from datetime import datetime, timezone

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.session import Session

logger = logging.getLogger(__name__)


async def auto_close_expired_sessions(db: AsyncSession) -> int:
    """Close all 'active' sessions whose end_time has passed.

    Returns the count of sessions that were closed.
    """
    now = datetime.now(timezone.utc)
    result = await db.execute(
        update(Session)
        .where(
            Session.status == "active",
            Session.end_time <= now,
            Session.deleted_at.is_(None),
        )
        .values(status="closed")
        .returning(Session.id)
    )
    closed_ids = result.scalars().all()
    count = len(closed_ids)

    if count > 0:
        await db.commit()
        logger.info(
            "Auto-closed %d expired sessions: %s",
            count,
            closed_ids,
        )
    return count


async def auto_activate_scheduled_sessions(db: AsyncSession) -> int:
    """Activate all 'scheduled' sessions whose start_time has passed.

    Returns the count of sessions that were activated.
    """
    now = datetime.now(timezone.utc)
    result = await db.execute(
        update(Session)
        .where(
            Session.status == "scheduled",
            Session.start_time <= now,
            Session.deleted_at.is_(None),
        )
        .values(status="active")
        .returning(Session.id)
    )
    activated_ids = result.scalars().all()
    count = len(activated_ids)

    if count > 0:
        await db.commit()
        logger.info(
            "Auto-activated %d scheduled sessions: %s",
            count,
            activated_ids,
        )
    return count


async def run_session_maintenance(db: AsyncSession) -> tuple[int, int]:
    """Run full session maintenance: activate expired + close expired.

    Returns (activated_count, closed_count).
    """
    activated = await auto_activate_scheduled_sessions(db)
    closed = await auto_close_expired_sessions(db)
    return activated, closed
