from __future__ import annotations
"""Time slots router — global period definitions."""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.time_slot import TimeSlot
from app.schemas.time_slot_schema import TimeSlotCreate, TimeSlotOut, TimeSlotList

router = APIRouter(prefix="/time-slots", tags=["Time Slots"])


@router.post("/", response_model=TimeSlotOut, status_code=201)
async def create_time_slot(
    body: TimeSlotCreate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> TimeSlotOut:
    """Create a new time slot (period)."""
    time_slot = TimeSlot(
        period_number=body.period_number,
        start_time=body.start_time,
        end_time=body.end_time,
    )
    db.add(time_slot)
    await db.commit()
    await db.refresh(time_slot)
    return TimeSlotOut.model_validate(time_slot)


@router.get("/", response_model=TimeSlotList)
async def list_time_slots(
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> TimeSlotList:
    """List all time slots ordered by period number."""
    result = await db.execute(
        select(TimeSlot).order_by(TimeSlot.period_number)
    )
    items = result.scalars().all()
    return TimeSlotList(total=len(items), items=[TimeSlotOut.model_validate(i) for i in items])


@router.get("/{slot_id}", response_model=TimeSlotOut)
async def get_time_slot(
    slot_id: int,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> TimeSlotOut:
    """Get a specific time slot by ID."""
    result = await db.execute(select(TimeSlot).where(TimeSlot.id == slot_id))
    time_slot = result.scalar_one_or_none()
    if not time_slot:
        from fastapi import HTTPException, status
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Time slot not found")
    return TimeSlotOut.model_validate(time_slot)
