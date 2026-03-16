"""User repository — raw async DB queries for the `users` table."""
import uuid
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


class UserRepository:
    """All database interactions for the User model.

    Never raises HTTP exceptions — that is the service layer's responsibility.
    Returns None when a record is not found.
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ── Read ──────────────────────────────────────────────────
    async def get_by_id(self, user_id: uuid.UUID) -> User | None:
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        result = await self.db.execute(
            select(User).where(User.email == email.lower())
        )
        return result.scalar_one_or_none()

    async def get_all(self, skip: int = 0, limit: int = 100) -> Sequence[User]:
        result = await self.db.execute(
            select(User).offset(skip).limit(limit).order_by(User.created_at.desc())
        )
        return result.scalars().all()

    async def count(self) -> int:
        from sqlalchemy import func as sa_func
        result = await self.db.execute(select(sa_func.count()).select_from(User))
        return result.scalar_one()

    # ── Write ─────────────────────────────────────────────────
    async def create(
        self,
        *,
        email: str,
        password_hash: str,
        full_name: str,
        role: str = "student",
    ) -> User:
        user = User(
            email=email.lower(),
            password_hash=password_hash,
            full_name=full_name,
            role=role,
        )
        self.db.add(user)
        await self.db.flush()   # get the UUID without committing
        await self.db.refresh(user)
        return user

    async def update_password(self, user: User, new_hash: str) -> User:
        user.password_hash = new_hash
        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def delete(self, user: User) -> None:
        await self.db.delete(user)
        await self.db.flush()
