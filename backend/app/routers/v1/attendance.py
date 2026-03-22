
"""v1 Attendance router — /api/v1/attendance endpoints (unified session-based)."""
import uuid
from fastapi import APIRouter, Depends, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.services.attendance_service import AttendanceService
from app.schemas.v1.attendance import (
    AttendanceCreate,
    CheckinRequest,
    CheckinResponse,
    AttendanceOut,
    AttendanceList,
    AttendanceSummary,
)

router = APIRouter(prefix="/attendance", tags=["v1 — Attendance"])


@router.post("/", response_model=AttendanceOut, status_code=status.HTTP_201_CREATED)
async def create_attendance(
    req: AttendanceCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new attendance record with full anti-cheat validation."""
    svc = AttendanceService(db)
    return await svc.create_attendance(req)


@router.post("/checkin", response_model=CheckinResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("30/minute")
async def realtime_checkin(
    request: Request,
    req: CheckinRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Real-time device-initiated check-in.

    Streamlined endpoint for face-recognition devices.
    Uses server time for all anti-cheat decisions (check-in window, late detection).
    All validation (device, enrollment, duplicate, check-in window) is applied.
    Rate limited: 30 attempts/minute per client IP.
    """
    svc = AttendanceService(db)
    return await svc.realtime_checkin(req)


@router.get("/session/{session_id}", response_model=AttendanceList)
async def get_by_session(
    session_id: uuid.UUID,
    skip: int = Query(0, ge=0),
    limit: int = Query(500, ge=1, le=2000),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get all attendance records for a session."""
    svc = AttendanceService(db)
    return await svc.get_by_session(session_id, skip=skip, limit=limit)


@router.get("/student/{student_id}", response_model=AttendanceList)
async def get_by_student(
    student_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get all attendance records for a student."""
    svc = AttendanceService(db)
    return await svc.get_by_student(student_id, skip=skip, limit=limit)


@router.get("/{attendance_id}", response_model=AttendanceOut)
async def get_attendance(
    attendance_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single attendance record by ID."""
    svc = AttendanceService(db)
    return await svc.get_attendance(attendance_id)


@router.delete("/{attendance_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_attendance(
    attendance_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete an attendance record."""
    svc = AttendanceService(db)
    await svc.delete_attendance(attendance_id, deleted_by=user_id)


@router.get("/summary/session/{session_id}", response_model=AttendanceSummary)
async def get_session_summary(
    session_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get attendance summary for a session (present/late/absent counts + rate)."""
    svc = AttendanceService(db)
    return await svc.get_session_summary(session_id)
