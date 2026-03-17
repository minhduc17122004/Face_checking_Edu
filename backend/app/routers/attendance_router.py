from __future__ import annotations
"""Attendance router — real-time check-in and history queries."""
import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.schemas.attendance_schema import CheckinRequest, AttendanceOut, AttendanceList
from app.services.attendance_service import AttendanceService

router = APIRouter(prefix="/attendance", tags=["Attendance"])


@router.post(
    "/checkin",
    response_model=AttendanceOut,
    status_code=201,
    summary="Record a single check-in / check-out",
)
async def checkin(
    body: CheckinRequest,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AttendanceOut:
    """Create a real-time attendance record for a student.

    Use `record_type: "checkout"` for check-outs.
    `checkin_time` defaults to the server's current UTC time if not provided.
    """
    return await AttendanceService(db).checkin(body)


@router.get(
    "/history",
    response_model=AttendanceList,
    summary="Global attendance history (paginated)",
)
async def get_history(
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=1000),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AttendanceList:
    """Return all attendance records, ordered by sync_time descending."""
    return await AttendanceService(db).get_history(skip=skip, limit=limit)


@router.get(
    "/student/{student_id}",
    response_model=AttendanceList,
    summary="Attendance history for a specific student",
)
async def get_by_student(
    student_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=1000),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AttendanceList:
    """Return attendance records for a specific student."""
    return await AttendanceService(db).get_by_student(student_id, skip=skip, limit=limit)


@router.get(
    "/class/{class_id}",
    response_model=AttendanceList,
    summary="Attendance records for a specific class",
)
async def get_by_class(
    class_id: uuid.UUID,
    skip: int = Query(0, ge=0),
    limit: int = Query(500, ge=1, le=5000),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AttendanceList:
    """Return all attendance records linked to a specific classroom."""
    return await AttendanceService(db).get_by_class(class_id, skip=skip, limit=limit)
