from __future__ import annotations
"""v1 Metrics router — /api/v1/metrics endpoint for system observability.

Phase 9: Exposes aggregate counts for monitoring attendance system health.
"""
from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.attendance_repository import AttendanceRepository
from app.repositories.session_repository import SessionRepository
from app.repositories.student_repository import StudentRepository

router = APIRouter(prefix="/metrics", tags=["v1 — Metrics"])


@router.get("/")
async def get_metrics(
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get system-wide attendance metrics.

    Returns aggregate counts for monitoring and observability:
    - Total and today's check-ins
    - Active sessions
    - Total registered students
    """
    att_repo = AttendanceRepository(db)
    session_repo = SessionRepository(db)
    student_repo = StudentRepository(db)

    checkin_total = await att_repo.count_total_checkins()
    checkin_today = await att_repo.count_today_checkins()
    active_sessions = await session_repo.count_active()
    total_students = await student_repo.count()

    return {
        "checkin_total": checkin_total,
        "checkin_today": checkin_today,
        "active_sessions": active_sessions,
        "total_students": total_students,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
