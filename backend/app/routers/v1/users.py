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
    role: str | None = Query(None, description="Filter by role: student, teacher, admin"),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all users, optionally filtered by role."""
    repo = UserRepository(db)
    users = await repo.get_all(skip=skip, limit=limit, role=role)
    total = await repo.count(role=role)
    items = []
    for u in users:
        out = UserOut.model_validate(u)
        if u.role == 'student' and getattr(u, 'student_profile', None):
            out.student_code = u.student_profile.student_code
        elif u.role == 'teacher' and getattr(u, 'teacher_profile', None):
            out.student_code = u.teacher_profile.employee_code
        items.append(out)
    return UserList(total=total, items=items)


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
