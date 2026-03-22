from __future__ import annotations
"""Unit tests for RoomService."""
import uuid
import pytest
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession


class TestRoomServiceCreate:
    """Tests for room creation."""

    async def test_create_room_success(self, db_session: AsyncSession):
        from app.models.room import Room
        from app.services.room_service import RoomService
        from app.schemas.v1.room import RoomCreate

        svc = RoomService(db_session)
        req = RoomCreate(
            code="A101",
            name="Phong A101",
            building="Toa A",
            floor=1,
            capacity=50,
        )
        result = await svc.create_room(req)

        assert result.code == "A101"
        assert result.name == "Phong A101"
        assert result.building == "Toa A"
        assert result.floor == 1
        assert result.capacity == 50
        assert result.deleted_at is None

    async def test_create_room_duplicate_code_fails(self, db_session: AsyncSession):
        from app.services.room_service import RoomService
        from app.schemas.v1.room import RoomCreate
        from fastapi import HTTPException

        svc = RoomService(db_session)
        req = RoomCreate(code="A101", name="Room 1")

        await svc.create_room(req)
        await db_session.commit()

        with pytest.raises(HTTPException) as exc_info:
            await svc.create_room(RoomCreate(code="A101", name="Room 2"))

        assert exc_info.value.status_code == 409
        assert "already exists" in exc_info.value.detail


class TestRoomServiceGet:
    """Tests for room retrieval."""

    async def test_get_room_by_code(self, db_session: AsyncSession):
        from app.models.room import Room
        from app.services.room_service import RoomService

        room = Room(code="B202", name="Room B202")
        db_session.add(room)
        await db_session.commit()

        svc = RoomService(db_session)
        result = await svc.get_room_by_code("B202")

        assert result.code == "B202"
        assert result.name == "Room B202"

    async def test_get_room_by_code_not_found(self, db_session: AsyncSession):
        from app.services.room_service import RoomService
        from fastapi import HTTPException

        svc = RoomService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            await svc.get_room_by_code("NONEXISTENT")

        assert exc_info.value.status_code == 404


class TestRoomServiceDelete:
    """Tests for room deletion with link checks."""

    async def test_delete_room_with_linked_course_fails(self, db_session: AsyncSession):
        from app.models.room import Room
        from app.models.course import Course
        from app.services.room_service import RoomService

        room = Room(code="C303", name="Room C303")
        db_session.add(room)
        await db_session.flush()

        course = Course(course_name="Test Course", room_id=room.id)
        db_session.add(course)
        await db_session.commit()

        svc = RoomService(db_session)

        with pytest.raises(Exception) as exc_info:
            await svc.delete_room(room.id)

        assert "linked courses" in str(exc_info.value).lower() or exc_info.value.status_code == 409

    async def test_delete_room_without_links_succeeds(self, db_session: AsyncSession):
        from app.models.room import Room
        from app.services.room_service import RoomService

        room = Room(code="D404", name="Room D404")
        db_session.add(room)
        await db_session.commit()

        svc = RoomService(db_session)
        await svc.delete_room(room.id)
        await db_session.commit()

        # Verify soft-deleted
        deleted_room = await svc.get_room(room.id)
        assert deleted_room.deleted_at is not None


class TestRoomServiceAssign:
    """Tests for assigning rooms to courses."""

    async def test_assign_room_to_course(self, db_session: AsyncSession):
        from app.models.room import Room
        from app.models.course import Course
        from app.services.room_service import RoomService

        room = Room(code="E505", name="Room E505")
        db_session.add(room)
        await db_session.flush()

        course = Course(course_name="Test Course")
        db_session.add(course)
        await db_session.flush()
        await db_session.commit()

        # Update course room via repository
        from app.repositories.course_repository import CourseRepository
        repo = CourseRepository(db_session)
        await repo.update(course, room_id=room.id)
        await db_session.commit()

        updated = await repo.get_by_id(course.id)
        assert updated.room_id == room.id
