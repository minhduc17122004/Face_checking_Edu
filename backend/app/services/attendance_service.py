from __future__ import annotations
"""Attendance service — unified session-based check-in with anti-cheat."""
import uuid
from datetime import datetime, timezone, timedelta
from typing import overload

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attendance import Attendance
from app.models.session import Session
from app.models.student import Student
from app.repositories.attendance_repository import AttendanceRepository
from app.repositories.student_repository import StudentRepository
from app.repositories.session_repository import SessionRepository
from app.schemas.v1.attendance import CheckinRequest, CheckinResponse
from app.schemas.attendance_new_schema import (
    AttendanceCreate,
    AttendanceOut,
    AttendanceList,
    AttendanceSummary,
    AttendanceWithDetails,
)
from app.services.anti_cheat_service import AntiCheatService
from app.services.audit_service import AuditService
from app.services.attendance_validator import AttendanceValidator
from app.core.distributed_lock import checkin_lock, LockAcquisitionError


class AttendanceService:
    """Unified attendance service using session-based check-in.

    All operations are protected by anti-cheat validation.
    Session status is auto-transitioned on every check-in.
    All mutations are audit-logged via AuditService.
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = AttendanceRepository(db)
        self.student_repo = StudentRepository(db)
        self.session_repo = SessionRepository(db)
        self.anti_cheat = AntiCheatService(db)
        self.validator = AttendanceValidator(db)
        self.audit = AuditService()

    # ── Session lifecycle ─────────────────────────────────────────────────────
    async def _ensure_session_active(self, session_id: uuid.UUID) -> None:
        """Auto-transition session status before any check-in.

        Rules:
        - scheduled → active  when current time >= start_time
        - active → closed     when current time >= end_time
        """
        session = await self.session_repo.get_by_id(session_id)
        if not session:
            return

        now = datetime.now(timezone.utc)
        changed = False

        if session.status == "scheduled" and session.start_time and session.start_time <= now:
            session.status = "active"
            changed = True
        elif session.status == "active" and session.end_time and session.end_time <= now:
            session.status = "closed"
            changed = True

        if changed:
            await self.db.flush()

    # ── Core check-in ────────────────────────────────────────────────────────
    @overload
    async def create_attendance(self, req: AttendanceCreate) -> AttendanceOut: ...

    @overload
    async def create_attendance(
        self,
        *,
        session_id: uuid.UUID,
        student_id: int,
        checkin_time: datetime,
        status: str = "present",
        confidence: float | None = None,
        device_id: uuid.UUID | None = None,
        sync_time: datetime | None = None,
    ) -> AttendanceOut: ...

    async def create_attendance(  # type: ignore[overload]
        self,
        req: AttendanceCreate | None = None,
        **kwargs,
    ) -> AttendanceOut:
        """Create attendance with full anti-cheat validation.

        Supports both schema-based and keyword-argument calls (for DeviceService bulk).

        Validates:
        1. Session auto-transition (scheduled→active, active→closed)
        2. Session exists and is active
        3. Student exists
        4. Student enrolled in course
        5. Device belongs to session's course
        6. Check-in is within allowed time window (respects attendance_mode)
        7. No duplicate attendance — idempotent: returns existing record
        """
        # Normalize arguments
        if req is not None:
            session_id = req.session_id
            student_id = req.student_id
            checkin_time = req.checkin_time
            attendance_status = req.status or "present"
            confidence = req.confidence
            device_id = req.device_id
            sync_time = req.sync_time
        else:
            session_id = kwargs["session_id"]
            student_id = kwargs["student_id"]
            checkin_time = kwargs["checkin_time"]
            attendance_status = kwargs.get("status", "present")
            confidence = kwargs.get("confidence")
            device_id = kwargs.get("device_id")
            sync_time = kwargs.get("sync_time")

        # 0. Auto-transition session status
        await self._ensure_session_active(session_id)

        # 1. Validate session exists
        ok, msg = await self.anti_cheat.validate_session_exists(session_id)
        if not ok:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=msg)

        # Get session for late detection
        session = await self.session_repo.get_by_id(session_id)

        # 2. Validate student
        student = await self.student_repo.get_by_id(student_id)
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Student {student_id} not found.",
            )

        # 3. Validate student enrolled in course
        ok, msg = await self.anti_cheat.validate_student_enrolled_in_course(
            session_id, student_id
        )
        if not ok:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Enrollment validation failed: {msg}",
            )

        # 4. Validate device (if provided)
        if device_id:
            ok, msg = await self.anti_cheat.validate_device_for_session(
                device_id, session_id
            )
            if not ok:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Device validation failed: {msg}",
                )
            await self.anti_cheat.update_device_last_active(device_id)

        # 5. Validate check-in window (respects attendance_mode)
        ok, msg = await self.anti_cheat.validate_checkin_window(
            session_id, checkin_time
        )
        if not ok:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Check-in window validation failed: {msg}",
            )

        # 6. Detect duplicate — idempotent: return existing record instead of raising 409
        existing = await self.repo.get_by_session_student(session_id, student_id)
        if existing:
            return AttendanceOut.model_validate(existing)

        # Auto-detect late status
        auto_status = attendance_status
        if session and session.effective_checkin_window_end:
            late_threshold = session.start_time + timedelta(minutes=15)
            if checkin_time > late_threshold:
                auto_status = "late"

        # Create record
        record = await self.repo.create(
            session_id=session_id,
            student_id=student_id,
            checkin_time=checkin_time,
            sync_time=sync_time or datetime.now(timezone.utc),
            status=auto_status,
            confidence=confidence,
            device_id=device_id,
        )
        self.audit.log_attendance_created(
            attendance_id=record.id,
            student_id=student_id,
            session_id=session_id,
            device_id=device_id,
            status=auto_status,
        )
        await self.db.commit()
        return AttendanceOut.model_validate(record)

    # ── Real-time check-in (device-initiated) ─────────────────────────────────
    async def realtime_checkin(self, req: CheckinRequest) -> CheckinResponse:
        """Device-initiated real-time check-in.

        Uses server time for all decisions (anti-cheat). Auto-detects
        present vs late based on the session's checkin window.
        All validation is delegated to create_attendance.

        Phase 9: Wrapped with distributed lock to prevent race conditions
        when multiple requests for the same session/student arrive simultaneously.
        """
        # Server-side timestamp used for all anti-cheat checks
        now = datetime.now(timezone.utc)

        try:
            async with checkin_lock(req.session_id, req.student_id):
                # Delegate to create_attendance for full validation pipeline
                record = await self.create_attendance(
                    session_id=req.session_id,
                    student_id=req.student_id,
                    checkin_time=now,
                    status="present",
                    confidence=req.confidence,
                    device_id=req.device_id,
                )
        except LockAcquisitionError:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests for this student. Please try again.",
            )

        return CheckinResponse(
            attendance_id=record.id,
            student_id=record.student_id,
            status=record.status,
            checkin_time=record.checkin_time,
            message=f"Check-in recorded as '{record.status}'.",
        )

    # ── Query ─────────────────────────────────────────────────────────────────
    async def get_attendance(self, attendance_id: uuid.UUID) -> AttendanceOut:
        record = await self.repo.get_by_id(attendance_id)
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Attendance {attendance_id} not found.",
            )
        return AttendanceOut.model_validate(record)

    async def get_by_session(
        self, session_id: uuid.UUID, skip: int = 0, limit: int = 1000
    ) -> AttendanceList:
        records = await self.repo.get_by_session(session_id, skip=skip, limit=limit)
        total = await self.repo.count_by_session(session_id)
        return AttendanceList(
            total=total,
            items=[AttendanceOut.model_validate(r) for r in records],
        )

    async def get_by_session_with_details(
        self, session_id: uuid.UUID, skip: int = 0, limit: int = 1000
    ) -> list[AttendanceWithDetails]:
        # Fixed N+1: use single JOIN query to fetch all data at once
        from sqlalchemy import select
        from app.models.course import Course as CourseModel
        stmt = (
            select(Attendance, Student, Session, CourseModel)
            .join(Student, Attendance.student_id == Student.id)
            .outerjoin(Session, Attendance.session_id == Session.id)
            .outerjoin(CourseModel, Session.course_id == CourseModel.id)
            .where(
                Attendance.session_id == session_id,
                Attendance.deleted_at.is_(None),
            )
            .offset(skip)
            .limit(limit)
            .order_by(Attendance.checkin_time.asc())
        )
        result = await self.db.execute(stmt)
        rows = result.all()
        return [
            AttendanceWithDetails(
                id=att.id,
                session_id=att.session_id,
                student_id=att.student_id,
                checkin_time=att.checkin_time,
                sync_time=att.sync_time,
                status=att.status,
                confidence=att.confidence,
                device_id=att.device_id,
                created_at=att.created_at,
                is_deleted=att.is_deleted,
                student_name=student.name if student else None,
                session_date=sess.start_time.date() if sess else None,
                classroom_name=crs.course_name if crs else None,
            )
            for att, student, sess, crs in rows
        ]

    async def get_by_student(
        self, student_id: int, skip: int = 0, limit: int = 200
    ) -> AttendanceList:
        student = await self.student_repo.get_by_id(student_id)
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Student {student_id} not found.",
            )
        records = await self.repo.get_by_student(student_id, skip=skip, limit=limit)
        return AttendanceList(
            total=len(records),
            items=[AttendanceOut.model_validate(r) for r in records],
        )

    async def get_history(self, skip: int = 0, limit: int = 200) -> AttendanceList:
        records = await self.repo.get_all(skip=skip, limit=limit)
        total = await self.repo.count()
        return AttendanceList(
            total=total,
            items=[AttendanceOut.model_validate(r) for r in records],
        )

    # ── Summary ────────────────────────────────────────────────────────────────
    async def get_session_summary(self, session_id: uuid.UUID) -> AttendanceSummary:
        session = await self.session_repo.get_by_id(session_id)
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Session {session_id} not found.",
            )

        total = await self.repo.count_by_session(session_id)
        present = await self.repo.count_by_status(session_id, "present")
        late = await self.repo.count_by_status(session_id, "late")
        absent = total - present - late

        return AttendanceSummary(
            session_id=session_id,
            total_students=total,
            present=present,
            late=late,
            absent=absent if absent >= 0 else 0,
            attendance_rate=round((present + late) / total * 100, 1) if total > 0 else 0.0,
        )

    # ── Soft delete ───────────────────────────────────────────────────────────
    async def delete_attendance(self, attendance_id: uuid.UUID, deleted_by: str = "system") -> None:
        record = await self.repo.get_by_id(attendance_id)
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Attendance {attendance_id} not found.",
            )
        self.audit.log_attendance_deleted(attendance_id=attendance_id, deleted_by=deleted_by)
        await self.repo.soft_delete(record)
