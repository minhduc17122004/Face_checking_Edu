from __future__ import annotations
"""v1 TimeSlots router — /api/v1/time-slots endpoints."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.time_slot_repository import TimeSlotRepository
from app.models.time_slot import TimeSlot
from app.schemas.v1.time_slot import TimeSlotCreate, TimeSlotOut, TimeSlotList

router = APIRouter(prefix="/time-slots", tags=["v1 — TimeSlots"])


@router.post("/", response_model=TimeSlotOut, status_code=status.HTTP_201_CREATED)
async def create_time_slot(
    req: TimeSlotCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new time slot."""
    slot = TimeSlot(
        period_number=req.period_number,
        start_time=req.start_time,
        end_time=req.end_time,
    )
    db.add(slot)
    await db.flush()
    await db.refresh(slot)
    return TimeSlotOut.model_validate(slot)


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
