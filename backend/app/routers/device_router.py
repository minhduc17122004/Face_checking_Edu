from __future__ import annotations
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.models.device import Device
from app.schemas.device_schema import DeviceCreate, DeviceResponse, ScheduleResponse

router = APIRouter(prefix="/devices", tags=["Devices"])

@router.post("/register", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
async def register_device(
    device_in: DeviceCreate,
    db: AsyncSession = Depends(get_db)
):
    # Check if exists
    result = await db.execute(select(Device).where(Device.device_code == device_in.device_code))
    existing = result.scalars().first()
    if existing:
        raise HTTPException(status_code=400, detail="Device already registered")
        
    device = Device(**device_in.model_dump())
    db.add(device)
    await db.commit()
    await db.refresh(device)
    return device

@router.get("/{room}/schedule/today", response_model=ScheduleResponse)
async def get_today_schedule(
    room: str,
    db: AsyncSession = Depends(get_db)
):
    # Dummy schedule response since exact schedule models are pending
    return ScheduleResponse(
        room=room,
        schedule=[
            {
                "section_id": "dummy-section-123",
                "subject_name": "Software Engineering",
                "start_slot": 1,
                "end_slot": 3,
            }
        ]
    )
