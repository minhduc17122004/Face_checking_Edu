from __future__ import annotations
"""Attendance service — unified session-based check-in with anti-cheat."""
import uuid
import logging
from datetime import datetime, timezone, timedelta
from typing import overload

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attendance import Attendance
from app.models.session import Session
from app.models.student import Student
from app.models.course import Course
from app.repositories.attendance_repository import AttendanceRepository
from app.repositories.student_repository import StudentRepository
from app.repositories.session_repository import SessionRepository
from app.repositories.course_enrollment_repository import CourseEnrollmentRepository
from app.schemas.v1.attendance import CheckinRequest, CheckinResponse
from app.schemas.v1.attendance_checkin import (
    ManualCheckinRequest,
    ManualCheckinResponse,
    AttendanceRecordResponse,
    AttendanceCheckinList,
    AttendanceSummaryResponse,
)
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
from app.services.attendance_config_service import AttendanceConfigService
from app.services.device_authorization_service import DeviceAuthorizationService
from app.core.distributed_lock import checkin_lock, LockAcquisitionError


logger = logging.getLogger(__name__)


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
        self.enrollment_repo = CourseEnrollmentRepository(db)
        self.anti_cheat = AntiCheatService(db)
        self.validator = AttendanceValidator(db)
        self.audit = AuditService(db)
        self.config_svc = AttendanceConfigService(db)
        self.device_auth = DeviceAuthorizationService(db)
        self._client_time_drift_tolerance = timedelta(minutes=20)

    def _normalized_client_timestamp(self, ts: datetime | None) -> datetime:
        """Normalize client timestamp to UTC and bound excessive drift."""
        now = datetime.now(timezone.utc)
        if ts is None:
            return now
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        normalized = ts.astimezone(timezone.utc)
        if abs(now - normalized) > self._client_time_drift_tolerance:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Client timestamp drift exceeds tolerance window.",
            )
        return normalized

    async def _resolve_session_by_room_timestamp(
        self,
        room_id: uuid.UUID,
        checkin_time: datetime,
    ) -> Session | None:
        """Resolve session using (room_id + timestamp) with grace window."""
        stmt = (
            select(Session)
            .join(Course, Session.course_id == Course.id)
            .options(
                joinedload(Session.course),
                joinedload(Session.attendance_config),
            )
            .where(
                Course.room_id == room_id,
                Session.deleted_at.is_(None),
                Course.deleted_at.is_(None),
                Session.start_time <= checkin_time,
            )
            .order_by(Session.start_time.desc())
        )
        result = await self.db.execute(stmt)
        candidates = result.unique().scalars().all()

        for candidate in candidates:
            late_allowance = 15
            if candidate.attendance_config:
                late_allowance = candidate.attendance_config.late_allowance
            effective_end = candidate.end_time + timedelta(minutes=late_allowance) if candidate.end_time else None
            if effective_end is None or checkin_time <= effective_end:
                return candidate
        return None

    # ── Phase 9: Time Window Validation ─────────────────────────────────────
    async def _validate_checkin_window(
        self,
        session_id: uuid.UUID,
        checkin_time: datetime,
    ) -> tuple[bool, str]:
        """Check if check-in is within the effective time window.

        Phase 9: Uses AttendanceConfig for early/late allowance if available,
        otherwise falls back to session's checkin_window_start/end.
        """
        session = await self.session_repo.get_by_id(session_id)
        if not session:
            return False, "Session not found"

        if session.status != "active":
            return False, f"Session is not active (status: {session.status})"

        # FLEXIBLE mode: no fixed window restriction.
        effective_mode = await self.config_svc.get_effective_mode(session_id)
        if effective_mode == "FLEXIBLE":
            return True, "OK"

        # Get effective window from config or session
        if session.attendance_config:
            early_min = session.attendance_config.early_allowance
            late_min = session.attendance_config.late_allowance
        else:
            early_min = 15
            late_min = 15

        effective_start = session.start_time - timedelta(minutes=early_min)
        effective_end = session.end_time + timedelta(minutes=late_min) if session.end_time else None

        if checkin_time < effective_start:
            return False, f"Too early — allowed from {effective_start.isoformat()}"
        if effective_end and checkin_time > effective_end:
            return False, f"Too late — window closed at {effective_end.isoformat()}"

        return True, "OK"

    # ── Phase 9: Manual Check-in ─────────────────────────────────────────────
    async def manual_checkin(
        self, req: ManualCheckinRequest
    ) -> ManualCheckinResponse:
        """POST /api/v1/attendance/check-in — device/admin manual check-in.

        Wrapped with distributed lock to prevent race conditions.
        """
        now = datetime.now(timezone.utc)
        checkin_time = self._normalized_client_timestamp(
            req.timestamp or req.checkin_time
        )

        resolved_session_id = req.session_id
        mapping_reason = "session_id"

        if resolved_session_id is None:
            if req.room_id is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="room_id is required when session_id is missing.",
                )
            resolved_session = await self._resolve_session_by_room_timestamp(
                req.room_id,
                checkin_time,
            )
            if not resolved_session:
                logger.info(
                    "checkin rejected: no session mapping room=%s student=%s ts=%s device=%s",
                    req.room_id,
                    req.student_id,
                    checkin_time.isoformat(),
                    req.device_id,
                )
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="No matching session found for room and timestamp.",
                )
            resolved_session_id = resolved_session.id
            mapping_reason = "room_timestamp"

        if req.device_id and req.room_id:
            ok, msg, device_uuid = await self.device_auth.check_device_room_binding_by_code(
                req.device_id,
                req.room_id,
            )
            if not ok:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Device-room validation failed: {msg}",
                )
            normalized_device_id = device_uuid
        else:
            normalized_device_id = None

        try:
            async with checkin_lock(resolved_session_id, req.student_id):
                # Delegate to create_attendance for full validation pipeline
                # skip_audit=True because we write our own "manual" audit record
                record = await self.create_attendance(
                    session_id=resolved_session_id,
                    student_id=req.student_id,
                    checkin_time=checkin_time,
                    status=req.status,
                    device_id=normalized_device_id,
                    skip_audit=True,
                )
                # Log manual check-in separately with "manual" action
                session_ref = await self.session_repo.get_by_id(resolved_session_id)
                mins_diff = None
                if session_ref and record.checkin_time:
                    mins_diff = int((record.checkin_time - session_ref.start_time).total_seconds() / 60)
                await self.audit.write_attendance_audit(
                    student_id=req.student_id,
                    session_id=resolved_session_id,
                    action="manual",
                    new_status=record.status,
                    old_status=None,
                    device_id=normalized_device_id,
                    minutes_diff=mins_diff,
                )
        except LockAcquisitionError:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests for this student. Please try again.",
            )

        # Get session for response
        session = await self.session_repo.get_by_id(resolved_session_id)
        minutes_diff = None
        if session and record.checkin_time:
            delta = record.checkin_time - session.start_time
            minutes_diff = int(delta.total_seconds() / 60)

        logger.info(
            "checkin mapped reason=%s room=%s session=%s student=%s status=%s device=%s ts=%s",
            mapping_reason,
            req.room_id,
            resolved_session_id,
            req.student_id,
            record.status,
            req.device_id,
            checkin_time.isoformat(),
        )

        return ManualCheckinResponse(
            attendance_id=record.id,
            student_id=record.student_id,
            session_id=record.session_id,
            status=record.status,
            checkin_time=record.checkin_time,
            minutes_diff=minutes_diff,
            message=f"Check-in recorded as '{record.status}'.",
        )

    # ── Phase 9: Session Check-in Records ─────────────────────────────────────
    async def get_session_checkins(
        self, session_id: uuid.UUID, skip: int = 0, limit: int = 1000
    ) -> AttendanceCheckinList:
        """GET /api/v1/attendance/session/{id}/checkins — attendance records with student info."""
        # JOIN query: attendance + student
        from sqlalchemy import select
        from app.models.student import Student
        stmt = (
            select(Attendance, Student)
            .join(Student, Attendance.student_id == Student.id)
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
        return AttendanceCheckinList(
            total=len(rows),
            items=[
                AttendanceRecordResponse(
                    id=att.id,
                    student_id=att.student_id,
                    student_name=student.name if student else None,
                    student_code=student.student_code if student else None,
                    checkin_time=att.checkin_time,
                    status=att.status,
                    minutes_diff=att.minutes_diff,
                    device_id=att.device_id,
                )
                for att, student in rows
            ],
        )

    # ── Phase 9: Enhanced Session Summary ────────────────────────────────────
    async def get_enhanced_summary(
        self, session_id: uuid.UUID
    ) -> AttendanceSummaryResponse:
        """GET /api/v1/attendance/session/{id}/summary — enhanced summary."""
        session = await self.session_repo.get_by_id(session_id)
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Session {session_id} not found.",
            )

        course_name = session.course.course_name if session.course else "Unknown"
        total = await self.repo.count_by_session(session_id)
        early = await self.repo.count_by_status(session_id, "early")
        on_time = await self.repo.count_by_status(session_id, "on_time")
        present = await self.repo.count_by_status(session_id, "present")
        late = await self.repo.count_by_status(session_id, "late")
        # Legacy "present" records count as on_time for display purposes
        on_time += present
        total_checked_in = early + on_time + late
        absent = max(0, total - total_checked_in)

        # Get total enrolled
        enrollments = await self.enrollment_repo.get_by_course(session.course_id)
        total_enrolled = len(enrollments)

        return AttendanceSummaryResponse(
            session_id=session_id,
            course_name=course_name,
            total_enrolled=total_enrolled,
            total_checked_in=total_checked_in,
            present=on_time,   # "present" field = on_time count (legacy compat)
            early=early,
            on_time=on_time,
            late=late,
            absent=absent,
            attendance_rate=round(total_checked_in / total_enrolled * 100, 1) if total_enrolled > 0 else 0.0,
        )

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
        minutes_diff: int | None = None,
        skip_audit: bool = False,
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
        5. Device is authorized via DeviceAuthorizationService (Phase 9)
        6. Check-in is within allowed time window (respects attendance_mode + Phase 9 config)
        7. No duplicate attendance — idempotent: returns existing record

        Phase 9 enhancements:
        - minutes_diff: signed diff from start_time in minutes
        - status: auto-detected as early / on_time / late
        - DB-backed audit log via AttendanceAuditLog table
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
            minutes_diff = None
            skip_audit = False
        else:
            session_id = kwargs["session_id"]
            student_id = kwargs["student_id"]
            checkin_time = kwargs["checkin_time"]
            attendance_status = kwargs.get("status", "present")
            confidence = kwargs.get("confidence")
            device_id = kwargs.get("device_id")
            sync_time = kwargs.get("sync_time")
            minutes_diff = kwargs.get("minutes_diff")
            skip_audit = kwargs.get("skip_audit", False)

        # 0. Auto-transition session status
        await self._ensure_session_active(session_id)

        # 1. Validate session exists
        ok, msg = await self.anti_cheat.validate_session_exists(session_id)
        if not ok:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=msg)

        # Get session for late detection and room_id
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

        # 4. Validate device authorization (Phase 9: use DeviceAuthorizationService)
        if device_id:
            ok, msg = await self.device_auth.check_device_access(device_id, session_id)
            if not ok:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Device authorization failed: {msg}",
                )
            await self.anti_cheat.update_device_last_active(device_id)

        # 5. Validate check-in window (Phase 9: uses AttendanceConfig)
        ok, msg = await self._validate_checkin_window(session_id, checkin_time)
        if not ok:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Check-in window validation failed: {msg}",
            )

        # 6. Detect duplicate — idempotent: return existing record instead of raising 409
        existing = await self.repo.get_by_session_student(session_id, student_id)
        if existing:
            return AttendanceOut.model_validate(existing)

        # Phase 9/10: Trust client-provided minutes_diff and status if passed
        # (e.g. from the mobile app's offline queue which implements the correct
        # late/on-time logic based on checkinWindowEnd or active session state).
        calculated_minutes_diff = minutes_diff
        auto_status = attendance_status

        if session and calculated_minutes_diff is None:
            # Fallback auto-detection for endpoints that do not provide minutes_diff
            # (e.g. manual fallback or raw hardware realtime checkins)
            delta = checkin_time - session.start_time
            calculated_minutes_diff = int(delta.total_seconds() / 60)
            if calculated_minutes_diff < 0:
                auto_status = "early"
            elif calculated_minutes_diff == 0:
                auto_status = "on_time"
            else:
                auto_status = "late"

        # Create record (flush only — caller decides when to commit)
        record = await self._persist_attendance(
            session_id=session_id,
            student_id=student_id,
            checkin_time=checkin_time,
            sync_time=sync_time,
            auto_status=auto_status,
            confidence=confidence,
            device_id=device_id,
            calculated_minutes_diff=calculated_minutes_diff,
            skip_audit=skip_audit,
        )
        await self.db.commit()
        return AttendanceOut.model_validate(record)

    # ── Internal persist helper (flush-only, no commit) ────────────────────────
    async def _persist_attendance(
        self,
        *,
        session_id: uuid.UUID,
        student_id: int,
        checkin_time: datetime,
        sync_time: datetime | None,
        auto_status: str,
        confidence: float | None,
        device_id: uuid.UUID | None,
        calculated_minutes_diff: int | None,
        skip_audit: bool,
    ) -> Attendance:
        """Low-level attendance writer — flush only (no commit).

        Used by both create_attendance (single, commits after) and
        bulk_checkin (batch, commits once at the very end).
        """
        record = await self.repo.create(
            session_id=session_id,
            student_id=student_id,
            checkin_time=checkin_time,
            sync_time=sync_time or datetime.now(timezone.utc),
            status=auto_status,
            confidence=confidence,
            device_id=device_id,
            minutes_diff=calculated_minutes_diff,
        )
        self.audit.log_attendance_created(
            attendance_id=record.id,
            student_id=student_id,
            session_id=session_id,
            device_id=device_id,
            status=auto_status,
            minutes_diff=calculated_minutes_diff,
        )
        if not skip_audit:
            await self.audit.write_attendance_audit(
                student_id=student_id,
                session_id=session_id,
                action="checkin",
                new_status=auto_status,
                old_status=None,
                device_id=device_id,
                minutes_diff=calculated_minutes_diff,
            )
        return record

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

    async def get_role_based_history(
        self,
        role: str,
        user_id: str,
        course_id: uuid.UUID | None = None,
        skip: int = 0,
        limit: int = 50,
    ):
        """GET /api/v1/attendance/history — role-based attendance history.

        - admin: all records (optionally filtered by course_id)
        - teacher: records from courses owned by the teacher
        - student: only the student's own records
        """
        try:
            from sqlalchemy import select, func
            from app.models.session import Session as SessionModel
            from app.models.course import Course as CourseModel
            from app.models.room import Room as RoomModel
            from app.models.student import Student as StudentModel
            from app.models.user import User as UserModel
            from app.schemas.v1.attendance_checkin import (
                AttendanceHistoryItem,
                AttendanceHistoryList,
            )
            from sqlalchemy.orm import selectinload

            # Base query with JOINs
            # Room is associated with Course (Phase 9), not directly with Session
            base_stmt = (
                select(Attendance, StudentModel, SessionModel, CourseModel, RoomModel, UserModel)
                .join(StudentModel, Attendance.student_id == StudentModel.id)
                .join(UserModel, StudentModel.user_id == UserModel.id)
                .join(SessionModel, Attendance.session_id == SessionModel.id)
                .join(CourseModel, SessionModel.course_id == CourseModel.id)
                .outerjoin(RoomModel, CourseModel.room_id == RoomModel.id)
                .where(Attendance.deleted_at.is_(None))
            )

            # Optional: ensure user_id is a UUID object
            if isinstance(user_id, str):
                user_uuid = uuid.UUID(user_id)
            else:
                user_uuid = user_id

            # Role-based filtering
            if role == "student":
                # Get student profile for this user
                user_res = await self.db.execute(
                    select(UserModel)
                    .options(selectinload(UserModel.student_profile))
                    .where(UserModel.id == user_uuid)
                )
                user_obj = user_res.scalar_one_or_none()
                if not user_obj or not user_obj.student_profile:
                    return AttendanceHistoryList(total=0, items=[])
                student_id = user_obj.student_profile.id
                base_stmt = base_stmt.where(Attendance.student_id == student_id)
            elif role == "teacher":
                # Get teacher profile for this user
                user_res = await self.db.execute(
                    select(UserModel)
                    .options(selectinload(UserModel.teacher_profile))
                    .where(UserModel.id == user_uuid)
                )
                user_obj = user_res.scalar_one_or_none()
                if not user_obj or not user_obj.teacher_profile:
                    return AttendanceHistoryList(total=0, items=[])
                teacher_id = user_obj.teacher_profile.id
                base_stmt = base_stmt.where(CourseModel.teacher_id == teacher_id)
            # admin: no additional filter

            # Optional course filter
            if course_id:
                base_stmt = base_stmt.where(CourseModel.id == course_id)

            # Count
            count_stmt = select(func.count(Attendance.id)).select_from(base_stmt.subquery())
            count_result = await self.db.execute(count_stmt)
            total = count_result.scalar_one()

            # Paginated data
            data_stmt = (
                base_stmt
                .order_by(Attendance.checkin_time.desc())
                .offset(skip)
                .limit(limit)
            )
            result = await self.db.execute(data_stmt)
            rows = result.all()

            items = []
            for att, student, session, course, room, user_item in rows:
                items.append(AttendanceHistoryItem(
                    id=att.id,
                    student_id=att.student_id,
                    student_name=user_item.full_name if user_item else None,
                    student_code=student.student_code if student else None,
                    session_id=att.session_id,
                    session_date=session.start_time if session else None,
                    course_name=course.course_name if course else None,
                    course_id=course.id if course else None,
                    room_name=room.name if room else None,
                    checkin_time=att.checkin_time,
                    status=att.status,
                    minutes_diff=att.minutes_diff,
                ))

            return AttendanceHistoryList(total=total, items=items)
        except Exception as e:
            # Fallback to base exception to ensure 500 contains some info
            raise e

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
        await self.audit.write_attendance_audit(
            student_id=record.student_id,
            session_id=record.session_id,
            action="delete",
            old_status=record.status,
        )
        await self.repo.soft_delete(record)

    # ── Teacher-specific context (Phase 11) ──────────────────────────────────
    async def get_active_or_next_session_for_teacher(
        self, user_id: uuid.UUID
    ) -> Session | None:
        """Find the most relevant session for a teacher's dashboard.

        Logic:
        1. Resolve teacher_id from user_id.
        2. Fetch active/upcoming sessions for this teacher.
        3. Return the first one (Repository handles active-first sorting).
        """
        from app.services.course_service import CourseService
        course_svc = CourseService(self.db)
        teacher_id = await course_svc.resolve_teacher_id_from_user(user_id)
        if not teacher_id:
            return None

        from app.repositories.session_repository import SessionRepository
        session_repo = SessionRepository(self.db)
        sessions = await session_repo.get_upcoming_sessions_by_teacher(
            teacher_id=teacher_id, limit=1
        )
        return sessions[0] if sessions else None

    # ── Phase 10: Bulk Check-in (device offline sync) ────────────────────────
    async def bulk_checkin(
        self,
        req,  # BulkCheckinRequest
    ):
        """POST /api/v1/attendance/bulk-check-in — batch sync from device offline queue.

        Processes each item independently:
        - Existing (duplicate) records are silently skipped (idempotent).
        - Individual failures do not abort the whole batch.
        - Returns per-item results with local_id for client-side reconciliation.
        """
        from app.schemas.v1.attendance_checkin import (
            BulkCheckinResponse,
            BulkCheckinItemResult,
        )

        results: list[BulkCheckinItemResult] = []
        succeeded = 0
        failed = 0
        skipped = 0

        for item in req.items:
            try:
                # Resolve session_id
                resolved_session_id = item.session_id
                if resolved_session_id is None:
                    # room_id + timestamp → session
                    checkin_time = item.timestamp or datetime.now(timezone.utc)
                    if item.timestamp and item.timestamp.tzinfo is None:
                        checkin_time = item.timestamp.replace(tzinfo=timezone.utc)
                    elif item.timestamp:
                        checkin_time = item.timestamp.astimezone(timezone.utc)

                    session = await self._resolve_session_by_room_timestamp(
                        item.room_id, checkin_time
                    )
                    if not session:
                        results.append(BulkCheckinItemResult(
                            local_id=item.local_id,
                            success=False,
                            error="No matching session found for room and timestamp.",
                        ))
                        failed += 1
                        continue
                    resolved_session_id = session.id
                else:
                    checkin_time = item.timestamp or datetime.now(timezone.utc)
                    if item.timestamp and item.timestamp.tzinfo is None:
                        checkin_time = item.timestamp.replace(tzinfo=timezone.utc)
                    elif item.timestamp:
                        checkin_time = item.timestamp.astimezone(timezone.utc)

                # Resolve true student_id
                resolved_student_id = item.student_id
                if item.server_user_id or item.pin:
                    from app.repositories.student_repository import StudentRepository
                    student_repo = StudentRepository(self.db)
                    student = None
                    if item.server_user_id:
                        student = await student_repo.get_by_user_id(item.server_user_id)
                    if not student and item.pin:
                        student = await student_repo.get_by_student_code_or_pin(item.pin)

                    if student:
                        resolved_student_id = student.id
                    else:
                        logger.warning(
                            "bulk_checkin could not resolve student for server_user_id=%s pin=%s, fallback to local int=%s",
                            item.server_user_id, item.pin, item.student_id
                        )

                # Check for duplicate (idempotent)
                existing = await self.repo.get_by_session_student(
                    resolved_session_id, resolved_student_id
                )
                if existing:
                    results.append(BulkCheckinItemResult(
                        local_id=item.local_id,
                        success=True,
                        attendance_id=existing.id,
                        skipped=True,
                    ))
                    skipped += 1
                    continue

                # Validate and auto-transition session before writing
                await self._ensure_session_active(resolved_session_id)

                # Calculate auto_status and minutes_diff matching create_attendance logic
                session_ref = await self.session_repo.get_by_id(resolved_session_id)
                provided_status = item.status or "present"
                provided_minutes_diff = getattr(item, "minutes_diff", None)

                if session_ref and provided_minutes_diff is None:
                    delta = checkin_time - session_ref.start_time
                    provided_minutes_diff = int(delta.total_seconds() / 60)
                    if provided_minutes_diff < 0:
                        provided_status = "early"
                    elif provided_minutes_diff == 0:
                        provided_status = "on_time"
                    else:
                        provided_status = "late"

                # Flush-only write — single commit after the full loop
                record = await self._persist_attendance(
                    session_id=resolved_session_id,
                    student_id=resolved_student_id,
                    checkin_time=checkin_time,
                    sync_time=None,
                    auto_status=provided_status,
                    confidence=None,
                    device_id=None,
                    calculated_minutes_diff=provided_minutes_diff,
                    skip_audit=True,
                )
                results.append(BulkCheckinItemResult(
                    local_id=item.local_id,
                    success=True,
                    attendance_id=record.id,
                    skipped=False,
                ))
                succeeded += 1

            except HTTPException as e:
                logger.warning(
                    "bulk_checkin item failed local_id=%s: %s",
                    item.local_id,
                    e.detail,
                )
                results.append(BulkCheckinItemResult(
                    local_id=item.local_id,
                    success=False,
                    error=str(e.detail),
                ))
                failed += 1
            except Exception as e:
                logger.exception(
                    "bulk_checkin unexpected error local_id=%s",
                    item.local_id,
                )
                results.append(BulkCheckinItemResult(
                    local_id=item.local_id,
                    success=False,
                    error=str(e),
                ))
                failed += 1

        # Commit all successfully flushed records in a single transaction
        if succeeded > 0:
            try:
                await self.db.commit()
            except Exception as commit_err:
                logger.exception("bulk_checkin commit failed: %s", commit_err)
                await self.db.rollback()
                # Mark all succeeded items as failed
                for r in results:
                    if r.success and not r.skipped:
                        r.success = False
                        r.attendance_id = None
                        r.error = "Commit failed, please retry."
                failed += succeeded
                succeeded = 0

        return BulkCheckinResponse(
            total=len(req.items),
            succeeded=succeeded,
            failed=failed,
            skipped=skipped,
            results=results,
        )
