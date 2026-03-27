from __future__ import annotations
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
from app.schemas.v1.attendance_checkin import (
    ManualCheckinRequest,
    ManualCheckinResponse,
    AttendanceCheckinList,
    AttendanceSummaryResponse,
    AttendanceHistoryList,
    BulkCheckinRequest,
    BulkCheckinResponse,
)

router = APIRouter(prefix="/attendance", tags=["v1 — Attendance"])


# ── History (role-based) ──────────────────────────────────────────────────

@router.get("/history", response_model=AttendanceHistoryList)
async def get_attendance_history(
    course_id: uuid.UUID | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/attendance/history — role-based attendance history.

    Automatically filters based on the authenticated user's role:
    - admin: all records (optionally filtered by course_id)
    - teacher: records from courses assigned to this teacher
    - student: only the student's own attendance records
    """
    from app.models.user import User
    from sqlalchemy import select as sa_select
    result = await db.execute(
        sa_select(User).where(User.id == uuid.UUID(user_id))
    )
    user = result.scalar_one_or_none()
    
    # Ensure role is lowercase so "TEACHER" matches "teacher" in the service logic 
    # and doesn't accidentally fall through to the admin (full access) view.
    role = user.role.lower() if user and user.role else "student"

    svc = AttendanceService(db)
    return await svc.get_role_based_history(
        role=role,
        user_id=user_id,
        course_id=course_id,
        skip=skip,
        limit=limit,
    )


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


# ── Phase 9: Manual check-in endpoints ──────────────────────────────────

@router.post(
    "/check-in",
    response_model=ManualCheckinResponse,
    status_code=status.HTTP_201_CREATED,
)
async def manual_checkin(
    req: ManualCheckinRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """POST /api/v1/attendance/check-in — device/admin manual check-in.

    Allows manual attendance entry for a specific student in a session.
    Uses distributed lock to prevent race conditions.
    Phase 9: validates against AttendanceConfig time windows.
    """
    svc = AttendanceService(db)
    return await svc.manual_checkin(req)


@router.post(
    "/bulk-check-in",
    response_model=BulkCheckinResponse,
    status_code=status.HTTP_200_OK,
)
async def bulk_checkin(
    req: BulkCheckinRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """POST /api/v1/attendance/bulk-check-in — batch sync from device offline queue.

    Phase 10: allows the tablet/device to push multiple pending check-ins
    accumulated in its local Hive queue in a single request.
    - Per-item result with success/failure/skipped status.
    - Duplicate records are silently skipped (idempotent).
    - Max 50 items per call.
    """
    svc = AttendanceService(db)
    return await svc.bulk_checkin(req)


@router.get("/session/{session_id}/checkins", response_model=AttendanceCheckinList)
async def get_session_checkins(
    session_id: uuid.UUID,
    skip: int = Query(0, ge=0),
    limit: int = Query(1000, ge=1, le=2000),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/attendance/session/{id}/checkins — attendance records with student info.

    Returns attendance records for a session including student names and codes.
    Used by the attendance check-in page.
    """
    svc = AttendanceService(db)
    return await svc.get_session_checkins(session_id, skip=skip, limit=limit)


@router.get("/session/{session_id}/summary", response_model=AttendanceSummaryResponse)
async def get_enhanced_session_summary(
    session_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/attendance/session/{id}/summary — enhanced summary.

    Returns attendance summary with total enrolled, checked in count, and rate.
    Phase 9: uses course enrollment for total_enrolled count.
    """
    svc = AttendanceService(db)
    return await svc.get_enhanced_summary(session_id)
