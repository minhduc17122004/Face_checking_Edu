from __future__ import annotations
"""v1 Schedules router — /api/v1/schedules endpoints."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.schedule_repository import ScheduleRepository
from app.repositories.classroom_repository import ClassroomRepository
from app.models.schedule import Schedule
from app.schemas.v1.schedule import (
    ScheduleCreate,
    ScheduleOut,
    ScheduleWithTimeSlot,
    ScheduleList,
)

router = APIRouter(prefix="/schedules", tags=["v1 — Schedules"])


@router.post("/", response_model=ScheduleOut, status_code=status.HTTP_201_CREATED)
async def create_schedule(
    req: ScheduleCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new schedule entry."""
    repo = ScheduleRepository(db)
    cls_repo = ClassroomRepository(db)

    classroom = await cls_repo.get_by_id(req.classroom_id)
    if not classroom or classroom.is_deleted:
        raise HTTPException(status_code=404, detail="Classroom not found.")

    schedule = Schedule(
        classroom_id=req.classroom_id,
        day_of_week=req.day_of_week,
        time_slot_id=req.time_slot_id,
        subject_name=req.subject_name,
    )
    db.add(schedule)
    await db.flush()
    await db.refresh(schedule)
    return ScheduleOut.model_validate(schedule)


@router.get("/", response_model=ScheduleList)
async def list_schedules(
    classroom_id: uuid.UUID | None = None,
    day_of_week: int | None = None,
    skip: int = 0,
    limit: int = 200,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List schedules with optional filters."""
    repo = ScheduleRepository(db)
    items, total = await repo.list(
        classroom_id=classroom_id,
        day_of_week=day_of_week,
        skip=skip,
        limit=limit,
    )
    return ScheduleList(total=total, items=[ScheduleOut.model_validate(s) for s in items])


@router.get("/{schedule_id}", response_model=ScheduleOut)
async def get_schedule(
    schedule_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single schedule."""
    repo = ScheduleRepository(db)
    schedule = await repo.get_by_id(schedule_id)
    if not schedule or schedule.is_deleted:
        raise HTTPException(status_code=404, detail="Schedule not found.")
    return ScheduleOut.model_validate(schedule)


@router.delete("/{schedule_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_schedule(
    schedule_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete a schedule."""
    repo = ScheduleRepository(db)
    schedule = await repo.get_by_id(schedule_id)
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found.")
    await repo.soft_delete(schedule)
