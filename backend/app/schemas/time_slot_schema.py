from __future__ import annotations
from datetime import time
from typing import Optional

import uuid
from pydantic import BaseModel, Field


class TimeSlotCreate(BaseModel):
    """POST /time-slots — create a new time slot."""

    period_number: int = Field(..., ge=1, examples=[1])
    start_time: time = Field(..., examples=["07:30:00"])
    end_time: time = Field(..., examples=["08:15:00"])


class TimeSlotOut(BaseModel):
    """Read response for a single time slot."""

    id: int
    period_number: int
    start_time: time
    end_time: time

    model_config = {"from_attributes": True}


class TimeSlotList(BaseModel):
    """Paginated wrapper for GET /time-slots."""

    total: int
    items: list[TimeSlotOut]
