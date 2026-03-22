from __future__ import annotations
"""New attendance router — uses the new attendance table tied to sessions."""
import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.attendance import Attendance
from app.models.session import Session
from app.models.student import Student
from app.schemas.attendance_new_schema import (
    AttendanceCreate,
    AttendanceOut,
    AttendanceWithDetails,
    AttendanceList,
    AttendanceSummary,
)
from app.services.anti_cheat_service import AntiCheatService

router = APIRouter(prefix="/attendance/new", tags=["Attendance (New)"])


@router.post("/", response_model=AttendanceOut, status_code=201)
async def create_attendance(
    body: AttendanceCreate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AttendanceOut:
    """Create a new attendance record tied to a session.

    This endpoint includes anti-cheat validation:
    - Device must belong to the session's course
    - Check-in must be within the allowed time window
    """
    anti_cheat = AntiCheatService(db)

    # Verify student exists
    result = await db.execute(
        select(Student).where(
            Student.id == body.student_id,
            Student.deleted_at.is_(None),
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    # Anti-cheat: Validate device for session
    if body.device_id:
        is_valid, msg = await anti_cheat.validate_device_for_session(
            body.device_id, body.session_id
        )
        if not is_valid:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=msg)

        # Update device last active time
        await anti_cheat.update_device_last_active(body.device_id)

    # Anti-cheat: Validate check-in window
    checkin_time = body.checkin_time or datetime.now(timezone.utc)
    is_valid, msg = await anti_cheat.validate_checkin_window(body.session_id, checkin_time)
    if not is_valid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=msg)

    # Check for duplicate attendance
    has_dup, msg = await anti_cheat.detect_duplicate_attendance(
        body.session_id, body.student_id
    )
    if has_dup:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=msg)

    # Set sync_time if not provided (server-side timestamp for offline support)
    sync_time = body.sync_time or datetime.now(timezone.utc)

    attendance = Attendance(
        session_id=body.session_id,
        student_id=body.student_id,
        user_id=body.user_id,
        checkin_time=checkin_time,
        sync_time=sync_time,
        status=body.status,
        confidence=body.confidence,
        device_id=body.device_id,
    )
    db.add(attendance)
    await db.commit()
    await db.refresh(attendance)
    return AttendanceOut.model_validate(attendance)


@router.get("/session/{session_id}", response_model=AttendanceList)
async def get_session_attendance(
    session_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AttendanceList:
    """Get all attendance records for a session (excluding soft-deleted)."""
    result = await db.execute(
        select(Attendance)
        .options(selectinload(Attendance.student))
        .where(
            Attendance.session_id == session_id,
            Attendance.deleted_at.is_(None),
        )
        .order_by(Attendance.checkin_time)
    )
    items = result.scalars().all()

    response_items = []
    for item in items:
        att = AttendanceOut.model_validate(item)
        att_with_details = AttendanceWithDetails(
            **att.model_dump(),
            student_name=item.student.name if item.student else None,
        )
        response_items.append(att_with_details)

    return AttendanceList(total=len(items), items=response_items)


@router.get("/student/{student_id}", response_model=AttendanceList)
async def get_student_attendance(
    student_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AttendanceList:
    """Get attendance records for a specific student."""
    result = await db.execute(
        select(Attendance)
        .options(
            selectinload(Attendance.session),
            selectinload(Attendance.student),
        )
        .where(
            Attendance.student_id == student_id,
            Attendance.deleted_at.is_(None),
        )
        .order_by(Attendance.checkin_time.desc())
        .offset(skip)
        .limit(limit)
    )
    items = result.scalars().all()
    total_result = await db.execute(
        select(func.count(Attendance.id)).where(
            Attendance.student_id == student_id,
            Attendance.deleted_at.is_(None),
        )
    )
    total = total_result.scalar_one()

    return AttendanceList(total=total, items=[AttendanceOut.model_validate(i) for i in items])


@router.get("/{attendance_id}", response_model=AttendanceOut)
async def get_attendance(
    attendance_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AttendanceOut:
    """Get a specific attendance record."""
    result = await db.execute(
        select(Attendance).where(
            Attendance.id == attendance_id,
            Attendance.deleted_at.is_(None),
        )
    )
    attendance = result.scalar_one_or_none()
    if not attendance:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendance not found")
    return AttendanceOut.model_validate(attendance)


@router.delete("/{attendance_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_attendance(
    attendance_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Soft delete an attendance record."""
    result = await db.execute(
        select(Attendance).where(
            Attendance.id == attendance_id,
            Attendance.deleted_at.is_(None),
        )
    )
    attendance = result.scalar_one_or_none()
    if not attendance:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendance not found")

    attendance.deleted_at = datetime.now(timezone.utc)
    await db.commit()


@router.get("/summary/session/{session_id}", response_model=AttendanceSummary)
async def get_session_attendance_summary(
    session_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AttendanceSummary:
    """Get attendance summary for a session."""
    present = await db.execute(
        select(func.count(Attendance.id)).where(
            Attendance.session_id == session_id,
            Attendance.status == "present",
            Attendance.deleted_at.is_(None),
        )
    )
    late = await db.execute(
        select(func.count(Attendance.id)).where(
            Attendance.session_id == session_id,
            Attendance.status == "late",
            Attendance.deleted_at.is_(None),
        )
    )
    absent = await db.execute(
        select(func.count(Attendance.id)).where(
            Attendance.session_id == session_id,
            Attendance.status == "absent",
            Attendance.deleted_at.is_(None),
        )
    )

    present_count = present.scalar_one()
    late_count = late.scalar_one()
    absent_count = absent.scalar_one()
    total = present_count + late_count + absent_count

    attendance_rate = (present_count + late_count) / total if total > 0 else 0.0

    return AttendanceSummary(
        session_id=session_id,
        total_students=total,
        present=present_count,
        late=late_count,
        absent=absent_count,
        attendance_rate=round(attendance_rate, 2),
    )
