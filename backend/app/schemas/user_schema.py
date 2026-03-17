from __future__ import annotations
"""User schemas — read/list responses for the /users endpoints."""
import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr


class UserOut(BaseModel):
    """Full user record returned from GET /users/{id} and GET /auth/me."""

    id: uuid.UUID
    email: EmailStr
    full_name: str
    role: str
    created_at: datetime

    model_config = {"from_attributes": True}


class UserList(BaseModel):
    """Paginated wrapper for GET /users."""

    total: int
    items: list[UserOut]
