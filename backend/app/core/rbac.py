from __future__ import annotations
"""RBAC decorator for FastAPI — enforces role-based access control."""
import functools
from typing import Callable, Sequence

from fastapi import Depends, HTTPException, status

from app.core.security import get_current_user_id
from app.core.database import AsyncSessionLocal
from app.repositories.user_repository import UserRepository


def require_role(*roles: str) -> Callable:
    """Decorator that enforces role-based access control.

    Usage:
        @router.get("/admin-only")
        async def admin_endpoint(
            user_id: str = Depends(get_current_user_id),
            user = Depends(require_role("admin")),
        ):
            return {"message": "Welcome admin"}

    Args:
        *roles: Allowed roles (e.g., "admin", "teacher", "student")
    """

    async def _check_role(user_id: str = Depends(get_current_user_id)) -> dict:
        async with AsyncSessionLocal() as db:
            repo = UserRepository(db)
            user = await repo.get_by_id(user_id)
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="User not found",
                )
            if user.role not in roles:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Access denied: requires role(s) {', '.join(roles)}",
                )
            return {"user_id": user.id, "role": user.role, "email": user.email}

    return _check_role
