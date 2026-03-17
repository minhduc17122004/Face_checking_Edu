from __future__ import annotations
"""User router — GET /users, GET /users/{user_id}."""
import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.schemas.user_schema import UserOut, UserList
from app.services.user_service import UserService

router = APIRouter(prefix="/users", tags=["Users"])


@router.get(
    "",
    response_model=UserList,
    summary="List all users (admin only in production)",
)
async def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    _: str = Depends(get_current_user_id),   # requires valid token
    db: AsyncSession = Depends(get_db),
) -> UserList:
    """Return a paginated list of all registered users."""
    return await UserService(db).list_users(skip=skip, limit=limit)


@router.get(
    "/{user_id}",
    response_model=UserOut,
    summary="Get a single user by UUID",
)
async def get_user(
    user_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> UserOut:
    """Return the full profile for a specific user."""
    return await UserService(db).get_user(user_id)
