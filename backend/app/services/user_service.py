"""User service — read-only queries for the /users endpoints."""
import uuid

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.user_repository import UserRepository
from app.schemas.user_schema import UserOut, UserList


class UserService:
    """Business logic for user listing and retrieval.

    Currently read-only: mutations go through AuthService (registration)
    or future admin endpoints.
    """

    def __init__(self, db: AsyncSession) -> None:
        self.repo = UserRepository(db)

    async def get_user(self, user_id: uuid.UUID) -> UserOut:
        user = await self.repo.get_by_id(user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User '{user_id}' not found.",
            )
        return UserOut.model_validate(user)

    async def list_users(self, skip: int = 0, limit: int = 100) -> UserList:
        users = await self.repo.get_all(skip=skip, limit=limit)
        total = await self.repo.count()
        return UserList(
            total=total,
            items=[UserOut.model_validate(u) for u in users],
        )
