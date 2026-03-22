from __future__ import annotations
"""Schedules router — weekly class schedule definitions."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.schedule import Schedule
from app.models.course import Course
from app.models.time_slot import TimeSlot
from app.schemas.schedule_schema import (
    ScheduleCreate,
    ScheduleOut,
    ScheduleWithTimeSlot,
    ScheduleList,
)

router = APIRouter(prefix="/schedules", tags=["Schedules"])


@router.post("/", response_model=ScheduleOut, status_code=201)
async def create_schedule(
    body: ScheduleCreate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> ScheduleOut:
    """Create a new weekly schedule entry."""
    result = await db.execute(
        select(Course).where(
            Course.id == body.course_id,
            Course.deleted_at.is_(None),
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found")

    result = await db.execute(
        select(TimeSlot).where(TimeSlot.id == body.time_slot_id)
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Time slot not found")

    result = await db.execute(
        select(Schedule).where(
            Schedule.course_id == body.course_id,
            Schedule.day_of_week == body.day_of_week,
            Schedule.time_slot_id == body.time_slot_id,
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Schedule already exists for this course, day, and time slot",
        )

    schedule = Schedule(
        course_id=body.course_id,
        day_of_week=body.day_of_week,
        time_slot_id=body.time_slot_id,
        room=body.room,
    )
    db.add(schedule)
    await db.commit()
    await db.refresh(schedule)
    return ScheduleOut.model_validate(schedule)


@router.get("/", response_model=ScheduleList)
async def list_schedules(
    course_id: uuid.UUID | None = Query(None),
    day_of_week: int | None = Query(None, ge=1, le=7),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> ScheduleList:
    """List schedules with optional filters."""
    query = select(Schedule).where(Schedule.deleted_at.is_(None))
    count_query = select(func.count(Schedule.id)).where(Schedule.deleted_at.is_(None))

    if course_id:
        query = query.where(Schedule.course_id == course_id)
        count_query = count_query.where(Schedule.course_id == course_id)
    if day_of_week is not None:
        query = query.where(Schedule.day_of_week == day_of_week)
        count_query = count_query.where(Schedule.day_of_week == day_of_week)

    query = query.options(selectinload(Schedule.time_slot)).order_by(
        Schedule.day_of_week, Schedule.time_slot_id
    )

    result = await db.execute(query)
    count_result = await db.execute(count_query)

    items = result.scalars().all()
    total = count_result.scalar_one()
    return ScheduleList(
        total=total,
        items=[ScheduleOut.model_validate(i) for i in items],
    )


@router.get("/{schedule_id}", response_model=ScheduleWithTimeSlot)
async def get_schedule(
    schedule_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> ScheduleWithTimeSlot:
    """Get a specific schedule with time slot details."""
    result = await db.execute(
        select(Schedule)
        .options(selectinload(Schedule.time_slot))
        .where(Schedule.id == schedule_id, Schedule.deleted_at.is_(None))
    )
    schedule = result.scalar_one_or_none()
    if not schedule:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Schedule not found")
    return ScheduleWithTimeSlot.model_validate(schedule)


@router.delete("/{schedule_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_schedule(
    schedule_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Soft delete a schedule."""
    result = await db.execute(
        select(Schedule).where(
            Schedule.id == schedule_id, Schedule.deleted_at.is_(None)
        )
    )
    schedule = result.scalar_one_or_none()
    if not schedule:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Schedule not found")

    schedule.deleted_at = func.now()
    await db.commit()
