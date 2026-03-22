from __future__ import annotations
"""v1 Rooms router — /api/v1/rooms endpoints."""
import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.services.room_service import RoomService
from app.schemas.v1.room import (
    RoomCreate,
    RoomUpdate,
    RoomOut,
    RoomList,
    AssignRoomRequest,
)
from app.schemas.v1.course import CourseOut

router = APIRouter(prefix="/rooms", tags=["v1 — Rooms"])


@router.post("", response_model=RoomOut, status_code=status.HTTP_201_CREATED)
async def create_room(
    req: RoomCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new room."""
    svc = RoomService(db)
    room = await svc.create_room(req, uuid.UUID(user_id) if user_id else None)
    await db.commit()
    return room


@router.get("", response_model=RoomList)
async def list_rooms(
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=500),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all active rooms (paginated)."""
    svc = RoomService(db)
    return await svc.list_rooms(skip=skip, limit=limit)


@router.get("/{room_id}", response_model=RoomOut)
async def get_room(
    room_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single room by ID."""
    svc = RoomService(db)
    return await svc.get_room(room_id)


@router.put("/{room_id}", response_model=RoomOut)
async def update_room(
    room_id: uuid.UUID,
    req: RoomUpdate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update a room."""
    svc = RoomService(db)
    room = await svc.update_room(room_id, req)
    await db.commit()
    return room


@router.delete("/{room_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_room(
    room_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete a room (fails if room has linked courses or devices)."""
    svc = RoomService(db)
    await svc.delete_room(room_id)
    await db.commit()


@router.get("/{room_id}/courses", response_model=List[CourseOut])
async def list_room_courses(
    room_id: uuid.UUID,
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=500),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all courses assigned to a specific room."""
    # Ensure room exists
    svc = RoomService(db)
    await svc.get_room(room_id)

    from sqlalchemy import select, and_
    from app.models.course import Course
    stmt = select(Course).where(
        and_(
            Course.room_id == room_id,
            Course.deleted_at.is_(None),
        )
    ).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return [CourseOut.model_validate(c) for c in result.scalars().all()]
