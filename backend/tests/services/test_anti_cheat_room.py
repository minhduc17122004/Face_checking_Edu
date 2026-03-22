from __future__ import annotations
"""Unit tests for anti-cheat room validation (Phase 9 FK-based matching)."""
import uuid
import pytest
from datetime import datetime, timezone, timedelta

from sqlalchemy.ext.asyncio import AsyncSession


class TestAntiCheatDeviceRoomValidation:
    """Tests for FK-based device-room validation in AntiCheatService."""

    async def test_validate_device_matching_room_passes(
        self, db_session: AsyncSession
    ):
        """Device and course share the same room_id — validation passes."""
        from app.models.room import Room
        from app.models.course import Course
        from app.models.device import Device
        from app.models.session import Session
        from app.services.anti_cheat_service import AntiCheatService

        room = Room(code="R101", name="Room 101")
        db_session.add(room)
        await db_session.flush()

        course = Course(course_name="Test Course", room_id=room.id)
        db_session.add(course)
        await db_session.flush()

        device = Device(device_code="DEV001", room_id=room.id, is_active=True)
        db_session.add(device)
        await db_session.flush()

        session = Session(
            course_id=course.id,
            session_date=datetime.now(timezone.utc).date(),
            start_time=datetime.now(timezone.utc) - timedelta(minutes=30),
            end_time=datetime.now(timezone.utc) + timedelta(minutes=30),
            status="active",
        )
        db_session.add(session)
        await db_session.commit()

        svc = AntiCheatService(db_session)
        ok, msg = await svc.validate_device_for_session(device.id, session.id)

        assert ok is True
        assert msg == "OK"

    async def test_validate_device_mismatched_room_fails(
        self, db_session: AsyncSession
    ):
        """Device and course have different room_id — validation fails."""
        from app.models.room import Room
        from app.models.course import Course
        from app.models.device import Device
        from app.models.session import Session
        from app.services.anti_cheat_service import AntiCheatService

        room1 = Room(code="R101", name="Room 101")
        room2 = Room(code="R102", name="Room 102")
        db_session.add(room1)
        db_session.add(room2)
        await db_session.flush()

        course = Course(course_name="Test Course", room_id=room1.id)
        db_session.add(course)
        await db_session.flush()

        device = Device(device_code="DEV001", room_id=room2.id, is_active=True)
        db_session.add(device)
        await db_session.flush()

        session = Session(
            course_id=course.id,
            session_date=datetime.now(timezone.utc).date(),
            start_time=datetime.now(timezone.utc) - timedelta(minutes=30),
            end_time=datetime.now(timezone.utc) + timedelta(minutes=30),
            status="active",
        )
        db_session.add(session)
        await db_session.commit()

        svc = AntiCheatService(db_session)
        ok, msg = await svc.validate_device_for_session(device.id, session.id)

        assert ok is False
        assert "room" in msg.lower()

    async def test_validate_device_null_room_allows_all(
        self, db_session: AsyncSession
    ):
        """Device with NULL room_id can be used for any course."""
        from app.models.room import Room
        from app.models.course import Course
        from app.models.device import Device
        from app.models.session import Session
        from app.services.anti_cheat_service import AntiCheatService

        room = Room(code="R101", name="Room 101")
        db_session.add(room)
        await db_session.flush()

        course = Course(course_name="Test Course", room_id=room.id)
        db_session.add(course)
        await db_session.flush()

        # Device has no room assignment
        device = Device(device_code="DEV001", is_active=True)
        db_session.add(device)
        await db_session.flush()

        session = Session(
            course_id=course.id,
            session_date=datetime.now(timezone.utc).date(),
            start_time=datetime.now(timezone.utc) - timedelta(minutes=30),
            end_time=datetime.now(timezone.utc) + timedelta(minutes=30),
            status="active",
        )
        db_session.add(session)
        await db_session.commit()

        svc = AntiCheatService(db_session)
        ok, msg = await svc.validate_device_for_session(device.id, session.id)

        assert ok is True
        assert msg == "OK"

    async def test_validate_course_null_room_allows_all_devices(
        self, db_session: AsyncSession
    ):
        """Course with NULL room_id accepts any device."""
        from app.models.room import Room
        from app.models.course import Course
        from app.models.device import Device
        from app.models.session import Session
        from app.services.anti_cheat_service import AntiCheatService

        room = Room(code="R101", name="Room 101")
        db_session.add(room)
        await db_session.flush()

        # Course has no room assigned
        course = Course(course_name="Test Course")
        db_session.add(course)
        await db_session.flush()

        device = Device(device_code="DEV001", room_id=room.id, is_active=True)
        db_session.add(device)
        await db_session.flush()

        session = Session(
            course_id=course.id,
            session_date=datetime.now(timezone.utc).date(),
            start_time=datetime.now(timezone.utc) - timedelta(minutes=30),
            end_time=datetime.now(timezone.utc) + timedelta(minutes=30),
            status="active",
        )
        db_session.add(session)
        await db_session.commit()

        svc = AntiCheatService(db_session)
        ok, msg = await svc.validate_device_for_session(device.id, session.id)

        assert ok is True
        assert msg == "OK"
