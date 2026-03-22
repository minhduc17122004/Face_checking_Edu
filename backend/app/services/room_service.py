from __future__ import annotations
"""Room service — business logic for the /rooms endpoints."""
import uuid

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.room import Room
from app.repositories.room_repository import RoomRepository
from app.schemas.v1.room import RoomCreate, RoomOut, RoomList, RoomUpdate


class RoomService:
    """Business logic for room management."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = RoomRepository(db)

    async def create_room(self, req: RoomCreate, created_by: uuid.UUID | None = None) -> RoomOut:
        name = req.name.strip()
        existing_name = await self.repo.get_by_name(name)
        if existing_name:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Room with name '{name}' already exists.",
            )

        max_seq = await self.repo.get_max_sequential_code()
        code = f"{max_seq + 1:04d}"

        building = None
        floor = None
        if len(name) >= 2:
            building = name[0].upper()
            if name[1].isdigit():
                floor = int(name[1])
            elif len(name) > 2 and name[1] == '-' and name[2].isdigit():
                floor = int(name[2])

        room = Room(
            code=code,
            name=name,
            building=building,
            floor=floor,
            capacity=req.capacity,
            created_by=created_by,
        )
        self.db.add(room)
        await self.db.flush()
        await self.db.refresh(room)
        return RoomOut.model_validate(room)

    async def get_room(self, room_id: uuid.UUID) -> RoomOut:
        room = await self.repo.get_by_id(room_id)
        if not room or room.is_deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Room '{room_id}' not found.",
            )
        return RoomOut.model_validate(room)

    async def get_room_by_code(self, code: str) -> RoomOut:
        room = await self.repo.get_by_code(code)
        if not room or room.is_deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Room with code '{code}' not found.",
            )
        return RoomOut.model_validate(room)

    async def list_rooms(
        self, skip: int = 0, limit: int = 200
    ) -> RoomList:
        rooms, total = await self.repo.list_active(skip=skip, limit=limit)
        return RoomList(
            total=total,
            items=[RoomOut.model_validate(r) for r in rooms],
        )

    async def update_room(
        self, room_id: uuid.UUID, req: RoomUpdate
    ) -> RoomOut:
        room = await self.repo.get_by_id(room_id)
        if not room or room.is_deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Room '{room_id}' not found.",
            )

        if req.code is not None:
            existing = await self.repo.get_by_code(req.code)
            if existing and existing.id != room_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Room with code '{req.code}' already exists.",
                )
            room.code = req.code

        if req.name is not None:
            name = req.name.strip()
            existing_name = await self.repo.get_by_name(name)
            if existing_name and existing_name.id != room_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Room with name '{name}' already exists.",
                )
            room.name = name
            
            if len(name) >= 2:
                room.building = name[0].upper()
                if name[1].isdigit():
                    room.floor = int(name[1])
                elif len(name) > 2 and name[1] == '-' and name[2].isdigit():
                    room.floor = int(name[2])
        if req.building is not None:
            room.building = req.building
        if req.floor is not None:
            room.floor = req.floor
        if req.capacity is not None:
            room.capacity = req.capacity

        await self.db.flush()
        await self.db.refresh(room)
        return RoomOut.model_validate(room)

    async def delete_room(self, room_id: uuid.UUID) -> None:
        room = await self.repo.get_by_id(room_id)
        if not room or room.is_deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Room '{room_id}' not found.",
            )

        # Check for linked courses
        from sqlalchemy import select, and_, func
        from app.models.course import Course
        course_count = await self.db.execute(
            select(func.count()).select_from(Course).where(
                and_(
                    Course.room_id == room_id,
                    Course.deleted_at.is_(None),
                )
            )
        )
        if course_count.scalar_one() > 0:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Cannot delete room with linked courses. Remove course-room assignments first.",
            )

        # Check for linked devices
        from app.models.device import Device
        device_count = await self.db.execute(
            select(func.count()).select_from(Device).where(
                and_(
                    Device.room_id == room_id,
                    Device.deleted_at.is_(None),
                )
            )
        )
        if device_count.scalar_one() > 0:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Cannot delete room with linked devices. Remove device-room assignments first.",
            )

        await self.repo.soft_delete(room)
