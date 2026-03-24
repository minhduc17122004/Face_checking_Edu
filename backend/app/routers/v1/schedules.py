from __future__ import annotations
"""v1 Schedules router — /api/v1/schedules endpoints."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from sqlalchemy import select
from app.core.database import get_db
from app.repositories.schedule_repository import ScheduleRepository
from app.repositories.course_repository import CourseRepository
from app.models.schedule import Schedule
from app.models.course import Course
from app.models.course_enrollment import CourseEnrollment
from app.core.security import get_current_user_id, get_current_user_obj
from app.schemas.v1.schedule import (
    ScheduleCreate,
    ScheduleUpdate,
    ScheduleOut,
    ScheduleWithTimeSlot,
    ScheduleListWithTimeSlot,
)

router = APIRouter(prefix="/schedules", tags=["v1 — Schedules"])


@router.post("/", response_model=ScheduleWithTimeSlot, status_code=status.HTTP_201_CREATED)
async def create_schedule(
    req: ScheduleCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new schedule entry."""
    repo = ScheduleRepository(db)
    course_repo = CourseRepository(db)

    course = await course_repo.get_by_id(req.course_id)
    if not course or not course.is_active:
        raise HTTPException(status_code=404, detail="Course not found.")

    schedule = Schedule(
        course_id=req.course_id,
        day_of_week=req.day_of_week,
        time_slot_id=req.time_slot_id,
    )
    db.add(schedule)
    await db.flush()
    await db.refresh(schedule, ["time_slot"])
    return ScheduleWithTimeSlot.model_validate(schedule)


@router.get("/", response_model=ScheduleListWithTimeSlot)
async def list_schedules(
    course_id: uuid.UUID | None = None,
    day_of_week: int | None = None,
    skip: int = 0,
    limit: int = 200,
    user=Depends(get_current_user_obj),
    db: AsyncSession = Depends(get_db),
):
    """List schedules with optional filters.
    
    Filters by role:
    - Admin: see all
    - Teacher: see schedules of courses they teach
    - Student: see schedules of courses they are enrolled in
    """
    repo = ScheduleRepository(db)
    
    teacher_id = None
    student_id = None
    
    if user.role == "teacher":
        if user.teacher_profile:
            teacher_id = user.teacher_profile.id
        else:
            return ScheduleListWithTimeSlot(total=0, items=[])
    elif user.role == "student":
        if user.student_profile:
            student_id = user.student_profile.id
        else:
            return ScheduleListWithTimeSlot(total=0, items=[])

    items, total = await repo.list(
        course_id=course_id,
        day_of_week=day_of_week,
        skip=skip,
        limit=limit,
        teacher_id=teacher_id,
        student_id=student_id,
    )
    return ScheduleListWithTimeSlot(total=total, items=[ScheduleWithTimeSlot.model_validate(s) for s in items])


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


@router.put("/{schedule_id}", response_model=ScheduleOut)
async def update_schedule(
    schedule_id: uuid.UUID,
    req: ScheduleUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update a schedule (day_of_week and/or time_slot)."""
    repo = ScheduleRepository(db)
    schedule = await repo.get_by_id(schedule_id)
    if not schedule or schedule.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Schedule not found.")
    updated = await repo.update(
        schedule,
        day_of_week=req.day_of_week,
        time_slot_id=req.time_slot_id,
    )
    return ScheduleOut.model_validate(updated)


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
