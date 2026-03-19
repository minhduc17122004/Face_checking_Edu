from __future__ import annotations
"""v1 Users router — /api/v1/users endpoints."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.user_repository import UserRepository
from app.schemas.v1.user import UserOut, UserList

router = APIRouter(prefix="/users", tags=["v1 — Users"])


@router.get("/", response_model=UserList)
async def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all users."""
    repo = UserRepository(db)
    users = await repo.get_all(skip=skip, limit=limit)
    total = await repo.count()
    return UserList(total=total, items=[UserOut.model_validate(u) for u in users])


@router.get("/{target_id}", response_model=UserOut)
async def get_user(
    target_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single user by ID."""
    repo = UserRepository(db)
    user = await repo.get_by_id(target_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    return UserOut.model_validate(user)
