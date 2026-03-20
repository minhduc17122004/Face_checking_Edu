from __future__ import annotations
"""Attendance service — unified session-based check-in with anti-cheat."""
import uuid
from datetime import datetime, timezone
from typing import overload

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.attendance_repository import AttendanceRepository
from app.repositories.student_repository import StudentRepository
from app.repositories.session_repository import SessionRepository
from app.schemas.attendance_new_schema import (
    AttendanceCreate,
    AttendanceOut,
    AttendanceList,
    AttendanceSummary,
    AttendanceWithDetails,
)
from app.services.anti_cheat_service import AntiCheatService
from app.services.audit_service import AuditService


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
        4. Device belongs to session's classroom
        5. Check-in is within allowed time window
        6. No duplicate attendance for this session + student
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

        # 1. Validate session is active
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

        # 3. Validate device (if provided)
        if device_id:
            ok, msg = await self.anti_cheat.validate_device_for_session(device_id, session_id)
            if not ok:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Device validation failed: {msg}",
                )
            await self.anti_cheat.update_device_last_active(device_id)

        # 4. Validate check-in window
        ok, msg = await self.anti_cheat.validate_checkin_window(session_id, checkin_time)
        if not ok:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Check-in window validation failed: {msg}",
            )

        # 5. Detect duplicate
        ok, msg = await self.anti_cheat.detect_duplicate_attendance(session_id, student_id)
        if not ok:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Duplicate attendance: {msg}",
            )

        # Auto-detect late status
        auto_status = attendance_status
        if session and session.checkin_end_time and checkin_time > session.checkin_end_time:
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
        return AttendanceOut.model_validate(record)

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
        records = await self.repo.get_by_session(session_id, skip=skip, limit=limit)
        result: list[AttendanceWithDetails] = []
        for r in records:
            student = await self.student_repo.get_by_id(r.student_id)
            session_obj = await self.session_repo.get_by_id(session_id)
            from app.models.course import Course as Classroom
            from sqlalchemy import select
            classroom_name = None
            if session_obj and session_obj.classroom_id:
                cr = await self.db.execute(
                    select(Classroom).where(Classroom.id == session_obj.classroom_id)
                )
                c = cr.scalar_one_or_none()
                if c:
                    classroom_name = c.class_name
            item = AttendanceWithDetails(
                id=r.id,
                session_id=r.session_id,
                student_id=r.student_id,
                checkin_time=r.checkin_time,
                sync_time=r.sync_time,
                status=r.status,
                confidence=r.confidence,
                device_id=r.device_id,
                created_at=r.created_at,
                is_deleted=r.is_deleted,
                student_name=student.name if student else None,
                session_date=session_obj.start_time.date() if session_obj else None,
                classroom_name=classroom_name,
            )
            result.append(item)
        return result

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
