from __future__ import annotations
"""Unit tests for AttendanceService."""
import uuid
import pytest
from datetime import datetime, timezone, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Course, Session, Student, CourseEnrollment, TimeSlot
from app.services.attendance_service import AttendanceService


class TestAttendanceValidator:
    """Tests for the centralized AttendanceValidator."""

    async def test_validate_session_not_found(self, db_session: AsyncSession):
        from app.services.attendance_validator import AttendanceValidator
        validator = AttendanceValidator(db_session)
        ok, msg = await validator.validate_session(uuid.uuid4())
        assert ok is False
        assert "not found" in msg.lower()

    async def test_validate_student_not_found(self, db_session: AsyncSession):
        from app.services.attendance_validator import AttendanceValidator
        validator = AttendanceValidator(db_session)
        ok, msg = await validator.validate_student(99999)
        assert ok is False
        assert "not found" in msg.lower()

    async def test_validate_checkin_window_flexible_always_passes(
        self, db_session: AsyncSession
    ):
        from app.models import Course
        from app.services.attendance_validator import AttendanceValidator
        course = Course(
            course_name="Test Course",
            attendance_mode="flexible",
            attendance_before_minutes=30,
            attendance_after_minutes=30,
        )
        db_session.add(course)
        await db_session.flush()

        session = Session(
            course_id=course.id,
            session_date=datetime.now(timezone.utc).date(),
            start_time=datetime.now(timezone.utc) - timedelta(hours=1),
            end_time=datetime.now(timezone.utc) + timedelta(hours=1),
            checkin_window_start=None,
            checkin_window_end=None,
            status="active",
        )
        db_session.add(session)
        await db_session.flush()

        validator = AttendanceValidator(db_session)
        ok, msg = await validator.validate_checkin_window(session.id, datetime.now(timezone.utc))
        assert ok is True
        assert msg == "OK"


class TestIdempotentCheckin:
    """Tests for idempotent check-in behavior."""

    async def test_duplicate_checkin_returns_existing(
        self, db_session: AsyncSession
    ):
        from app.models import Course, Session, Student, CourseEnrollment, TimeSlot
        from app.services.attendance_service import AttendanceService
        from datetime import date

        # Setup: create course, student, session
        course = Course(
            course_name="Test Course",
            attendance_mode="preset",
            attendance_before_minutes=30,
            attendance_after_minutes=30,
        )
        db_session.add(course)
        await db_session.flush()

        time_slot = TimeSlot(
            slot_name="Morning",
            start_time=datetime.strptime("08:00", "%H:%M").time(),
            end_time=datetime.strptime("09:00", "%H:%M").time(),
        )
        db_session.add(time_slot)
        await db_session.flush()

        student = Student(
            student_code="ST001",
            name="Test Student",
            email="test@test.com",
        )
        db_session.add(student)
        await db_session.flush()

        enrollment = CourseEnrollment(
            course_id=course.id,
            student_id=student.id,
        )
        db_session.add(enrollment)

        session = Session(
            course_id=course.id,
            session_date=date.today(),
            start_time=datetime.now(timezone.utc) - timedelta(minutes=30),
            end_time=datetime.now(timezone.utc) + timedelta(minutes=30),
            checkin_window_start=datetime.now(timezone.utc) - timedelta(minutes=30),
            checkin_window_end=datetime.now(timezone.utc) + timedelta(minutes=30),
            status="active",
        )
        db_session.add(session)
        await db_session.flush()
        await db_session.commit()

        svc = AttendanceService(db_session)

        # First check-in — creates record
        result1 = await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=datetime.now(timezone.utc),
        )
        assert result1.id is not None

        # Second check-in — returns existing record (idempotent)
        result2 = await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=datetime.now(timezone.utc),
        )
        assert result2.id == result1.id


class TestSessionAutoTransition:
    """Tests for session auto-transition on check-in."""

    async def test_scheduled_session_auto_activates(
        self, db_session: AsyncSession
    ):
        from app.models import Course, Session, Student, CourseEnrollment
        from datetime import date

        course = Course(
            course_name="Test Course",
            attendance_mode="preset",
        )
        db_session.add(course)
        await db_session.flush()

        student = Student(student_code="ST001", name="Test Student", email="test@test.com")
        db_session.add(student)
        await db_session.flush()

        enrollment = CourseEnrollment(course_id=course.id, student_id=student.id)
        db_session.add(enrollment)

        session = Session(
            course_id=course.id,
            session_date=date.today(),
            start_time=datetime.now(timezone.utc) - timedelta(minutes=5),
            end_time=datetime.now(timezone.utc) + timedelta(minutes=55),
            checkin_window_start=datetime.now(timezone.utc) - timedelta(minutes=30),
            checkin_window_end=datetime.now(timezone.utc) + timedelta(minutes=30),
            status="scheduled",
        )
        db_session.add(session)
        await db_session.flush()
        await db_session.commit()

        svc = AttendanceService(db_session)
        result = await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=datetime.now(timezone.utc),
        )
        assert result.id is not None
