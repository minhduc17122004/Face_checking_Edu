from __future__ import annotations
"""Centralized attendance validator — all attendance operations must pass through this."""
import uuid
from datetime import datetime, timezone

from sqlalchemy import select, and_
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.session import Session
from app.models.student import Student
from app.models.device import Device
from app.models.attendance import Attendance
from app.models.course_enrollment import CourseEnrollment


class AttendanceValidator:
    """Centralized attendance validator.

    All attendance operations must be validated via this class.
    Each method returns tuple[bool, str]: (is_valid, error_message).
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def validate_session(
        self, session_id: uuid.UUID
    ) -> tuple[bool, str]:
        """Validate session exists and is not deleted."""
        result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()
        if not session:
            return False, "Session not found."
        if session.is_deleted:
            return False, "Session has been cancelled."
        return True, "OK"

    async def validate_session_active(
        self, session_id: uuid.UUID
    ) -> tuple[bool, str]:
        """Validate session status is 'active' (not scheduled/closed)."""
        result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()
        if not session:
            return False, "Session not found."
        if session.is_deleted:
            return False, "Session has been cancelled."
        if session.status != "active":
            return False, f"Session is not active (current status: {session.status})."
        return True, "OK"

    async def validate_student(
        self, student_id: int
    ) -> tuple[bool, str]:
        """Validate student exists."""
        result = await self.db.execute(
            select(Student).where(Student.id == student_id)
        )
        student = result.scalar_one_or_none()
        if not student:
            return False, f"Student {student_id} not found."
        return True, "OK"

    async def validate_enrolled(
        self, session_id: uuid.UUID, student_id: int
    ) -> tuple[bool, str]:
        """Validate student is enrolled in the session's course."""
        session_result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = session_result.scalar_one_or_none()
        if not session:
            return False, "Session not found."

        enrollment_result = await self.db.execute(
            select(CourseEnrollment).where(
                and_(
                    CourseEnrollment.course_id == session.course_id,
                    CourseEnrollment.student_id == student_id,
                    CourseEnrollment.deleted_at.is_(None),
                )
            )
        )
        enrollment = enrollment_result.scalar_one_or_none()
        if not enrollment:
            return False, "Student is not enrolled in this course."
        return True, "OK"

    async def validate_device(
        self, device_id: uuid.UUID, session_id: uuid.UUID
    ) -> tuple[bool, str]:
        """Validate device is active, installed in the session's course room, and not deleted.

        Phase 9: FK-based room matching — device.room_id == course.room_id.
        If either device.room_id or course.room_id is NULL, validation passes.
        """
        device_result = await self.db.execute(
            select(Device).where(Device.id == device_id)
        )
        device = device_result.scalar_one_or_none()
        if not device:
            return False, "Device not found."
        if device.is_deleted:
            return False, "Device has been deactivated."
        if not device.is_active:
            return False, "Device is not active."

        session_result = await self.db.execute(
            select(Session)
            .options(joinedload(Session.course))
            .where(Session.id == session_id)
        )
        session = session_result.scalar_one_or_none()
        if not session:
            return False, "Session not found."

        # FK-based room matching: device.room_id == course.room_id
        if device.room_id is None:
            return True, "OK"  # Device not assigned, allow all

        if session.course is None:
            return True, "OK"  # Session has no course

        if session.course.room_id is None:
            return True, "OK"  # Course has no room assigned

        if device.room_id != session.course.room_id:
            return False, "Device room does not match course room."

        return True, "OK"

    async def validate_checkin_window(
        self, session_id: uuid.UUID, checkin_time: datetime
    ) -> tuple[bool, str]:
        """Validate checkin_time is within the allowed window.

        Respects course attendance_mode:
        - preset: use checkin_window_start/end (start ± before/after_minutes)
        - flexible: always allow (no window restriction)
        - custom: use checkin_window_start/end from session
        """
        result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()
        if not session:
            return False, "Session not found."
        if session.status != "active":
            return False, f"Session is not active (current status: {session.status})."

        mode = session.attendance_mode
        if mode == "flexible":
            return True, "OK"

        window_start = session.effective_checkin_window_start
        window_end = session.effective_checkin_window_end

        if window_start and checkin_time < window_start:
            return False, "Check-in not allowed yet."
        if window_end and checkin_time > window_end:
            return False, "Check-in window has closed."
        return True, "OK"

    async def get_existing_attendance(
        self, session_id: uuid.UUID, student_id: int
    ) -> Attendance | None:
        """Return existing attendance record if one exists, else None."""
        result = await self.db.execute(
            select(Attendance).where(
                and_(
                    Attendance.session_id == session_id,
                    Attendance.student_id == student_id,
                    Attendance.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one_or_none()

    async def validate_all(
        self,
        session_id: uuid.UUID,
        student_id: int,
        device_id: uuid.UUID | None = None,
        checkin_time: datetime | None = None,
    ) -> tuple[bool, str | None]:
        """Run all validations in one pass.

        Returns (is_valid, error_message).
        Stops at the first failure and returns its error message.
        """
        # 1. Session exists + active
        ok, msg = await self.validate_session_active(session_id)
        if not ok:
            return False, msg

        # 2. Student exists
        ok, msg = await self.validate_student(student_id)
        if not ok:
            return False, msg

        # 3. Student enrolled in course
        ok, msg = await self.validate_enrolled(session_id, student_id)
        if not ok:
            return False, msg

        # 4. Device valid (optional)
        if device_id:
            ok, msg = await self.validate_device(device_id, session_id)
            if not ok:
                return False, msg

        # 5. Time window valid
        if checkin_time:
            ok, msg = await self.validate_checkin_window(session_id, checkin_time)
            if not ok:
                return False, msg

        # 6. No duplicate
        existing = await self.get_existing_attendance(session_id, student_id)
        if existing:
            return False, f"Student {student_id} already has attendance in this session."

        return True, None
