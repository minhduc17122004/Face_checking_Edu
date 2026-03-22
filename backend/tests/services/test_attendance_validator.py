from __future__ import annotations
"""Unit tests for AttendanceValidator."""
import uuid
import pytest
from datetime import datetime, timezone, timedelta

from sqlalchemy.ext.asyncio import AsyncSession


class TestAttendanceValidatorSession:
    """Tests for session validation in AttendanceValidator."""

    async def test_validate_session_active_returns_true_for_active_session(
        self, db_session: AsyncSession
    ):
        from app.models import Course, Session
        course = Course(course_name="Test", attendance_mode="preset")
        db_session.add(course)
        await db_session.flush()

        session = Session(
            course_id=course.id,
            session_date=datetime.now(timezone.utc).date(),
            start_time=datetime.now(timezone.utc) - timedelta(minutes=30),
            end_time=datetime.now(timezone.utc) + timedelta(minutes=30),
            status="active",
        )
        db_session.add(session)
        await db_session.flush()
        await db_session.commit()

        from app.services.attendance_validator import AttendanceValidator
        validator = AttendanceValidator(db_session)
        ok, msg = await validator.validate_session_active(session.id)
        assert ok is True

    async def test_validate_session_active_returns_false_for_scheduled(
        self, db_session: AsyncSession
    ):
        from app.models import Course, Session
        course = Course(course_name="Test", attendance_mode="preset")
        db_session.add(course)
        await db_session.flush()

        session = Session(
            course_id=course.id,
            session_date=datetime.now(timezone.utc).date(),
            start_time=datetime.now(timezone.utc) + timedelta(minutes=30),
            end_time=datetime.now(timezone.utc) + timedelta(minutes=90),
            status="scheduled",
        )
        db_session.add(session)
        await db_session.flush()
        await db_session.commit()

        from app.services.attendance_validator import AttendanceValidator
        validator = AttendanceValidator(db_session)
        ok, msg = await validator.validate_session_active(session.id)
        assert ok is False
        assert "not active" in msg.lower()


class TestAttendanceValidatorEnrolled:
    """Tests for enrollment validation in AttendanceValidator."""

    async def test_validate_enrolled_returns_false_for_non_enrolled_student(
        self, db_session: AsyncSession
    ):
        from app.models import Course, Session, Student
        course = Course(course_name="Test", attendance_mode="preset")
        db_session.add(course)
        await db_session.flush()

        session = Session(
            course_id=course.id,
            session_date=datetime.now(timezone.utc).date(),
            start_time=datetime.now(timezone.utc) - timedelta(minutes=30),
            end_time=datetime.now(timezone.utc) + timedelta(minutes=30),
            status="active",
        )
        db_session.add(session)

        student = Student(student_code="ST001", name="Test Student", email="test@test.com")
        db_session.add(student)
        await db_session.flush()
        await db_session.commit()

        from app.services.attendance_validator import AttendanceValidator
        validator = AttendanceValidator(db_session)
        ok, msg = await validator.validate_enrolled(session.id, student.id)
        assert ok is False
        assert "not enrolled" in msg.lower()

    async def test_validate_enrolled_returns_true_for_enrolled_student(
        self, db_session: AsyncSession
    ):
        from app.models import Course, Session, Student, CourseEnrollment
        course = Course(course_name="Test", attendance_mode="preset")
        db_session.add(course)
        await db_session.flush()

        session = Session(
            course_id=course.id,
            session_date=datetime.now(timezone.utc).date(),
            start_time=datetime.now(timezone.utc) - timedelta(minutes=30),
            end_time=datetime.now(timezone.utc) + timedelta(minutes=30),
            status="active",
        )
        db_session.add(session)

        student = Student(student_code="ST001", name="Test Student", email="test@test.com")
        db_session.add(student)
        await db_session.flush()

        enrollment = CourseEnrollment(course_id=course.id, student_id=student.id)
        db_session.add(enrollment)
        await db_session.flush()
        await db_session.commit()

        from app.services.attendance_validator import AttendanceValidator
        validator = AttendanceValidator(db_session)
        ok, msg = await validator.validate_enrolled(session.id, student.id)
        assert ok is True
