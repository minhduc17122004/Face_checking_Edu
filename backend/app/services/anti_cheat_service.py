from __future__ import annotations
"""Anti-cheat service for attendance validation."""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import joinedload

from app.models.device import Device
from app.models.session import Session
from app.models.attendance import Attendance
from app.models.course_enrollment import CourseEnrollment


class AntiCheatService:
    """Validates attendance against anti-cheat rules.

    All methods return tuple[bool, str] where:
    - bool: True = valid/pass, False = invalid/fail
    - str: "OK" on pass, human-readable error message on fail
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def validate_session_exists(
        self, session_id: uuid.UUID
    ) -> tuple[bool, str]:
        """Verify session exists, is not deleted, and has a valid status."""
        result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()

        if not session:
            return False, "Session not found"
        if session.is_deleted:
            return False, "Session has been cancelled"
        return True, "OK"

    async def validate_device_for_session(
        self, device_id: uuid.UUID, session_id: uuid.UUID
    ) -> tuple[bool, str]:
        """Verify device is installed in the same room as the course.

        Returns:
            tuple[bool, str]: (is_valid, message)

        Phase 9: FK-based room matching — device.room_id == course.room_id
        If either device.room_id or course.room_id is NULL, validation passes
        (flexible mode — device not bound to a specific room).
        """
        result = await self.db.execute(select(Device).where(Device.id == device_id))
        device = result.scalar_one_or_none()

        if not device:
            return False, "Device not found"

        if device.is_deleted:
            return False, "Device has been deactivated"

        if not device.is_active:
            return False, "Device is not active"

        result = await self.db.execute(
            select(Session)
            .options(joinedload(Session.course))
            .where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()

        if not session:
            return False, "Session not found"

        if session.is_deleted:
            return False, "Session has been cancelled"

        # FK-based room matching: device.room_id == course.room_id
        if device.room_id is None:
            return True, "OK"  # Device not assigned to any room, allow all

        if session.course is None:
            return True, "OK"  # Session has no course, allow all

        if session.course.room_id is None:
            return True, "OK"  # Course has no room assigned, allow all

        if device.room_id != session.course.room_id:
            return False, "Device room does not match course room"

        return True, "OK"

    async def validate_checkin_window(
        self,
        session_id: uuid.UUID,
        checkin_time: datetime,
    ) -> tuple[bool, str]:
        """Check if checkin is within allowed window.

        Respects course attendance_mode:
        - flexible: always allow
        - fixed/custom: use checkin_window_start/end

        Returns:
            tuple[bool, str]: (is_valid, message)
        """
        result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()

        if not session:
            return False, "Session not found"

        if session.status != "active":
            return False, f"Session is not active (current status: {session.status})"

        # flexible mode: no window restriction
        if session.attendance_mode == "flexible":
            return True, "OK"

        # fixed/custom: use window
        window_start = session.effective_checkin_window_start
        window_end = session.effective_checkin_window_end

        if window_start and checkin_time < window_start:
            return False, "Check-in not allowed yet"
        if window_end and checkin_time > window_end:
            return False, "Check-in window has closed"

        return True, "OK"

    async def validate_student_enrolled_in_course(
        self,
        session_id: uuid.UUID,
        student_id: int,
    ) -> tuple[bool, str]:
        """Verify student is enrolled in the session's course."""
        session_result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = session_result.scalar_one_or_none()
        if not session:
            return False, "Session not found"

        result = await self.db.execute(
            select(CourseEnrollment).where(
                CourseEnrollment.course_id == session.course_id,
                CourseEnrollment.student_id == student_id,
            )
        )
        enrollment = result.scalar_one_or_none()
        if not enrollment:
            return False, "Student is not enrolled in this course"
        return True, "OK"

    async def validate_teacher_belongs_to_department(
        self,
        course_id: uuid.UUID,
        teacher_user_id: str,
    ) -> tuple[bool, str]:
        """Verify teacher teaching this course belongs to the course's department."""
        from app.models.course import Course
        from app.models.teacher import Teacher
        from app.models.user import User

        # Get course
        course_result = await self.db.execute(
            select(Course).where(Course.id == course_id)
        )
        course = course_result.scalar_one_or_none()
        if not course:
            return False, "Course not found"

        if not course.department_id:
            return True, "OK"  # No department required

        # Get teacher
        teacher_result = await self.db.execute(
            select(Teacher).where(
                Teacher.user_id == uuid.UUID(teacher_user_id),
                Teacher.deleted_at.is_(None),
            )
        )
        teacher = teacher_result.scalar_one_or_none()
        if not teacher:
            return False, "Teacher profile not found"

        if teacher.department_id != course.department_id:
            return False, "Teacher does not belong to the course's department"

        return True, "OK"

    async def detect_duplicate_attendance(
        self,
        session_id: uuid.UUID,
        student_id: int,
        exclude_id: Optional[uuid.UUID] = None,
    ) -> tuple[bool, str]:
        """Check if student has already been marked present in this session.

        Returns:
            tuple[bool, str]: (has_duplicate, message)
        """
        query = select(Attendance).where(
            Attendance.session_id == session_id,
            Attendance.student_id == student_id,
            Attendance.deleted_at.is_(None),
        )

        result = await self.db.execute(query)
        existing = result.scalar_one_or_none()

        if existing and (exclude_id is None or existing.id != exclude_id):
            return True, f"Student {student_id} already has attendance in this session"

        return False, "OK"

    async def update_device_last_active(
        self, device_id: uuid.UUID
    ) -> None:
        """Update device last_active_at timestamp."""
        result = await self.db.execute(select(Device).where(Device.id == device_id))
        device = result.scalar_one_or_none()

        if device:
            device.last_active_at = datetime.now(timezone.utc)
            await self.db.flush()
