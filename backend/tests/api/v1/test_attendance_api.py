from __future__ import annotations
"""API integration tests for attendance endpoints."""
import uuid
import pytest


class TestAttendanceEndpoints:
    """Tests for /api/v1/attendance/* endpoints."""

    async def test_create_attendance_requires_auth(self, client):
        """POST /api/v1/attendance/ requires auth token."""
        response = await client.post(
            "/api/v1/attendance/",
            json={
                "session_id": str(uuid.uuid4()),
                "student_id": 1,
                "checkin_time": "2026-03-21T08:00:00Z",
            },
        )
        assert response.status_code == 401

    async def test_get_session_summary_requires_auth(self, client):
        """GET /api/v1/attendance/summary/session/{id} requires auth token."""
        response = await client.get(
            f"/api/v1/attendance/summary/session/{uuid.uuid4()}",
        )
        assert response.status_code == 401

    async def test_get_by_session_requires_auth(self, client):
        """GET /api/v1/attendance/session/{id} requires auth token."""
        response = await client.get(
            f"/api/v1/attendance/session/{uuid.uuid4()}",
        )
        assert response.status_code == 401
