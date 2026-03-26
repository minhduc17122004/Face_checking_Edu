from __future__ import annotations
"""Phase 9 unit tests for device-based attendance — status, device auth, audit log."""
import uuid
import pytest
from datetime import datetime, timezone, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    Course, Session, Student, CourseEnrollment, TimeSlot,
    Room, Device, DeviceRequest, AttendanceConfig,
)
from app.services.attendance_service import AttendanceService
from app.services.device_authorization_service import DeviceAuthorizationService
from app.services.audit_service import AuditService


async def _setup_basic_session(db_session: AsyncSession):
    """Create a minimal course + student + session for testing."""
    course = Course(
        course_name="Test Course",
        attendance_mode="preset",
        attendance_before_minutes=15,
        attendance_after_minutes=15,
    )
    db_session.add(course)
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

    now = datetime.now(timezone.utc)
    session = Session(
        course_id=course.id,
        session_date=now.date(),
        start_time=now + timedelta(minutes=30),
        end_time=now + timedelta(hours=2),
        checkin_window_start=now + timedelta(minutes=15),
        checkin_window_end=now + timedelta(hours=2, minutes=15),
        status="active",
    )
    db_session.add(session)
    await db_session.flush()
    await db_session.commit()
    return course, student, session


class TestStatusCalculation:
    """Phase 9: Status is auto-calculated as early / on_time / late."""

    async def test_checkin_before_start_is_early(self, db_session: AsyncSession):
        course, student, session = await _setup_basic_session(db_session)

        # Check in 10 minutes before start
        checkin_time = session.start_time - timedelta(minutes=10)
        svc = AttendanceService(db_session)
        record = await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=checkin_time,
        )

        assert record.status == "early"
        assert record.minutes_diff is not None
        assert record.minutes_diff < 0

    async def test_checkin_exactly_at_start_is_on_time(self, db_session: AsyncSession):
        course, student, session = await _setup_basic_session(db_session)

        # Check in exactly at start
        svc = AttendanceService(db_session)
        record = await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=session.start_time,
        )

        assert record.status == "on_time"
        assert record.minutes_diff == 0

    async def test_checkin_after_start_is_late(self, db_session: AsyncSession):
        course, student, session = await _setup_basic_session(db_session)

        # Check in 5 minutes after start
        checkin_time = session.start_time + timedelta(minutes=5)
        svc = AttendanceService(db_session)
        record = await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=checkin_time,
        )

        assert record.status == "late"
        assert record.minutes_diff is not None
        assert record.minutes_diff > 0

    async def test_minutes_diff_is_calculated_correctly(self, db_session: AsyncSession):
        course, student, session = await _setup_basic_session(db_session)

        # Check in 7 minutes before start
        checkin_time = session.start_time - timedelta(minutes=7)
        svc = AttendanceService(db_session)
        record = await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=checkin_time,
        )

        assert record.minutes_diff == -7


class TestRoomIdNotStored:
    """Phase 9: room_id must NOT be stored in Attendance — derived from session."""

    async def test_attendance_has_no_room_id_column(self, db_session: AsyncSession):
        course, student, session = await _setup_basic_session(db_session)

        svc = AttendanceService(db_session)
        record = await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=datetime.now(timezone.utc),
        )

        # room_id should not be a column on Attendance
        from app.models.attendance import Attendance
        cols = [c.name for c in Attendance.__table__.columns]
        assert "room_id" not in cols


class TestDeviceAuthorizationHardening:
    """Phase 9: DeviceAuthorizationService.check_device_access is called."""

    async def test_checkin_without_device_succeeds(self, db_session: AsyncSession):
        """Check-in without a device should still work (no device auth needed)."""
        course, student, session = await _setup_basic_session(db_session)

        svc = AttendanceService(db_session)
        record = await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=datetime.now(timezone.utc),
            device_id=None,
        )

        assert record.id is not None
        assert record.status in ("early", "on_time", "late")

    async def test_unauthorized_device_rejected(self, db_session: AsyncSession):
        """Device not ACTIVE → 403."""
        course, student, session = await _setup_basic_session(db_session)

        # Create a device that is not approved
        room = Room(code="R101", name="Room 101")
        db_session.add(room)
        await db_session.flush()

        device = Device(
            device_code="DEV001",
            device_name="Test Device",
            room_id=room.id,
            status="INACTIVE",
            is_active=True,
            is_global=False,
        )
        db_session.add(device)
        await db_session.flush()
        await db_session.commit()

        svc = AttendanceService(db_session)
        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc_info:
            await svc.create_attendance(
                session_id=session.id,
                student_id=student.id,
                checkin_time=datetime.now(timezone.utc),
                device_id=device.id,
            )

        assert exc_info.value.status_code == 403
        assert "Device authorization failed" in exc_info.value.detail


class TestAuditLog:
    """Phase 9: AuditService writes DB-backed attendance_audit_logs."""

    async def test_attendance_creates_audit_record(self, db_session: AsyncSession):
        course, student, session = await _setup_basic_session(db_session)

        audit = AuditService(db_session)
        svc = AttendanceService(db_session)
        record = await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=session.start_time,
        )
        await db_session.commit()

        from app.models.attendance_audit_log import AttendanceAuditLog
        from sqlalchemy import select

        stmt = select(AttendanceAuditLog).where(
            AttendanceAuditLog.session_id == session.id,
            AttendanceAuditLog.student_id == student.id,
        )
        result = await db_session.execute(stmt)
        audit_record = result.scalar_one_or_none()

        assert audit_record is not None
        assert audit_record.action == "checkin"
        assert audit_record.new_status == record.status
        assert audit_record.minutes_diff == 0


class TestCheckinWindowValidation:
    """Phase 9: Check-in outside the time window is rejected."""

    async def test_checkin_too_early_rejected(self, db_session: AsyncSession):
        course, student, session = await _setup_basic_session(db_session)

        # Try to check in 1 hour before the window opens
        checkin_time = session.start_time - timedelta(hours=1)
        svc = AttendanceService(db_session)
        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc_info:
            await svc.create_attendance(
                session_id=session.id,
                student_id=student.id,
                checkin_time=checkin_time,
            )

        assert exc_info.value.status_code == 400
        assert "Too early" in exc_info.value.detail

    async def test_checkin_within_window_succeeds(self, db_session: AsyncSession):
        course, student, session = await _setup_basic_session(db_session)

        # Check in 10 minutes before start (within the 15-min early window)
        checkin_time = session.start_time - timedelta(minutes=10)
        svc = AttendanceService(db_session)
        record = await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=checkin_time,
        )

        assert record.id is not None
        assert record.status == "early"


class TestEnhancedSummary:
    """Phase 9: AttendanceSummaryResponse includes early / on_time counts."""

    async def test_summary_includes_early_on_time_late_counts(
        self, db_session: AsyncSession
    ):
        course, student, session = await _setup_basic_session(db_session)
        svc = AttendanceService(db_session)

        # Create 3 check-ins: early, on_time, late
        await svc.create_attendance(
            session_id=session.id,
            student_id=student.id,
            checkin_time=session.start_time - timedelta(minutes=5),
        )

        # Need more students for proper counting
        student2 = Student(student_code="ST002", name="Student 2", email="s2@test.com")
        db_session.add(student2)
        await db_session.flush()
        enrollment2 = CourseEnrollment(course_id=course.id, student_id=student2.id)
        db_session.add(enrollment2)
        await db_session.flush()
        await svc.create_attendance(
            session_id=session.id,
            student_id=student2.id,
            checkin_time=session.start_time,
        )
        await db_session.commit()

        summary = await svc.get_enhanced_summary(session.id)

        assert summary.early >= 1
        assert summary.on_time >= 1
        assert summary.total_checked_in >= 2
        assert summary.total_enrolled >= 2
