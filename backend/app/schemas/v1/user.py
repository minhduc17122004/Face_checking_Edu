from __future__ import annotations
from datetime import datetime
import uuid
from pydantic import BaseModel, EmailStr


class UserOut(BaseModel):
    id: uuid.UUID
    email: EmailStr
    full_name: str
    role: str
    avatar_url: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class UserList(BaseModel):
    total: int
    items: list[UserOut]
