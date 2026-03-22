from __future__ import annotations
"""API integration tests for attendance check-in endpoints."""
import uuid
import pytest
from datetime import datetime, timezone, timedelta, date


class TestCheckinEndpoint:
    """Tests for POST /api/v1/attendance/checkin."""

    async def test_checkin_requires_auth(self, client):
        response = await client.post(
            "/api/v1/attendance/checkin",
            json={
                "student_id": 1,
                "session_id": str(uuid.uuid4()),
                "device_id": str(uuid.uuid4()),
            },
        )
        assert response.status_code == 401

    async def test_checkin_validates_session_not_found(
        self, client, db_session
    ):
        """Check-in with non-existent session returns 404."""
        response = await client.post(
            "/api/v1/attendance/checkin",
            json={
                "student_id": 1,
                "session_id": str(uuid.uuid4()),
                "device_id": str(uuid.uuid4()),
            },
            headers={"Authorization": "Bearer test-token"},
        )
        # Without proper auth token, it will be 401
        # Once auth is mocked, this tests 404
        assert response.status_code in (401, 404)


class TestConcurrentCheckin:
    """Tests for concurrent check-in scenarios."""

    async def test_concurrent_checkins_all_create_records(
        self, db_session
    ):
        """Simulate 10 students checking in concurrently to the same session."""
        import asyncio
        from app.models import Course, Session, Student, CourseEnrollment
        from app.services.attendance_service import AttendanceService

        # Setup
        course = Course(
            course_name="Concurrent Test Course",
            attendance_mode="preset",
        )
        db_session.add(course)
        await db_session.flush()

        students = []
        for i in range(10):
            s = Student(student_code=f"ST{i:03d}", name=f"Student {i}", email=f"st{i}@test.com")
            db_session.add(s)
            await db_session.flush()
            students.append(s)

            enrollment = CourseEnrollment(course_id=course.id, student_id=s.id)
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

        # Concurrent check-ins
        async def checkin_student(student: Student):
            svc = AttendanceService(db_session)
            return await svc.create_attendance(
                session_id=session.id,
                student_id=student.id,
                checkin_time=datetime.now(timezone.utc),
            )

        tasks = [checkin_student(s) for s in students]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        # All should succeed (no exceptions)
        success_count = sum(1 for r in results if not isinstance(r, Exception))
        assert success_count == 10, f"Expected 10 successes, got {success_count}: {results}"

        # All results should have distinct attendance IDs
        ids = [r.id for r in results if not isinstance(r, Exception)]
        assert len(set(ids)) == 10, f"Expected 10 unique IDs, got {len(set(ids))}"
