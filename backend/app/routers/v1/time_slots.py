from __future__ import annotations
"""v1 TimeSlots router — /api/v1/time-slots endpoints."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.time_slot_repository import TimeSlotRepository
from app.models.time_slot import TimeSlot
from app.schemas.v1.time_slot import TimeSlotCreate, TimeSlotOut, TimeSlotList, TimeSlotUpdate

router = APIRouter(prefix="/time-slots", tags=["v1 — TimeSlots"])


@router.post("/", response_model=TimeSlotOut, status_code=status.HTTP_201_CREATED)
async def create_time_slot(
    req: TimeSlotCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new time slot."""
    try:
        slot = TimeSlot(
            period_number=req.period_number,
            start_time=req.start_time,
            end_time=req.end_time,
        )
        db.add(slot)
        await db.flush()
        await db.refresh(slot)
        return TimeSlotOut.model_validate(slot)
    except Exception as exc:
        if "duplicate key" in str(exc).lower() or "unique" in str(exc).lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Tiết {req.period_number} đã tồn tại.",
            )
        raise


@router.get("/", response_model=TimeSlotList)
async def list_time_slots(
    skip: int = 0,
    limit: int = 100,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all time slots ordered by period number."""
    repo = TimeSlotRepository(db)
    items = await repo.list(skip=skip, limit=limit)
    return TimeSlotList(total=len(items), items=[TimeSlotOut.model_validate(s) for s in items])


@router.get("/{slot_id}", response_model=TimeSlotOut)
async def get_time_slot(
    slot_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single time slot by ID."""
    repo = TimeSlotRepository(db)
    slot = await repo.get_by_id(slot_id)
    if not slot:
        raise HTTPException(status_code=404, detail="Time slot not found.")
    return TimeSlotOut.model_validate(slot)


@router.put("/{slot_id}", response_model=TimeSlotOut)
@router.patch("/{slot_id}", response_model=TimeSlotOut)
async def update_time_slot(
    slot_id: int,
    req: TimeSlotUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update a time slot."""
    repo = TimeSlotRepository(db)
    slot = await repo.get_by_id(slot_id)
    if not slot:
        raise HTTPException(status_code=404, detail="Time slot not found.")

    try:
        if req.period_number is not None:
            slot.period_number = req.period_number
        if req.start_time is not None:
            slot.start_time = req.start_time
        if req.end_time is not None:
            slot.end_time = req.end_time

        await db.flush()

        from datetime import datetime
        from sqlalchemy import select, and_, or_
        from app.models.schedule import Schedule
        from app.models.session import Session
        from app.models.course import Course
        from app.services.session_generator_service import SessionGeneratorService, VIETNAM_TZ

        gen_svc = SessionGeneratorService(db)

        schedules_result = await db.execute(
            select(Schedule).where(Schedule.time_slot_id == slot_id)
        )
        schedules = schedules_result.scalars().all()

        today_date = datetime.now(VIETNAM_TZ).date()

        for sched in schedules:
            sessions_result = await db.execute(
                select(Session).where(
                    and_(
                        Session.schedule_id == sched.id,
                        Session.deleted_at.is_(None),
                        Session.session_date >= today_date,
                        or_(
                            Session.status == "scheduled",
                            Session.status == "active"
                        )
                    )
                )
            )
            sessions = sessions_result.scalars().all()

            for sess in sessions:
                course_result = await db.execute(
                    select(Course).where(Course.id == sess.course_id)
                )
                course = course_result.scalar_one_or_none()
                if not course:
                    continue

                start_dt = gen_svc._combine_date_time(sess.session_date, slot.start_time)
                end_dt = gen_svc._combine_date_time(sess.session_date, slot.end_time)

                chk_start, chk_end = gen_svc._compute_checkin_window(course, start_dt, end_dt)

                sess.start_time = start_dt
                sess.end_time = end_dt
                sess.checkin_window_start = chk_start
                sess.checkin_window_end = chk_end

        await db.flush()
        await db.refresh(slot)
        return TimeSlotOut.model_validate(slot)
    except Exception as exc:
        if "duplicate key" in str(exc).lower() or "unique" in str(exc).lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Tiết {req.period_number} đã tồn tại.",
            )
        raise


@router.delete("/{slot_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_time_slot(
    slot_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Delete a time slot."""
    repo = TimeSlotRepository(db)
    slot = await repo.get_by_id(slot_id)
    if not slot:
        raise HTTPException(status_code=404, detail="Time slot not found.")
    await db.delete(slot)
    await db.flush()
