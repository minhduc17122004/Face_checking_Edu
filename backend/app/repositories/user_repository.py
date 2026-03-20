from __future__ import annotations
"""User repository — raw async DB queries for the `users` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, and_
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
    async def get_by_id(self, user_id: str | uuid.UUID) -> User | None:
        uid = uuid.UUID(str(user_id)) if not isinstance(user_id, uuid.UUID) else user_id
        result = await self.db.execute(
            select(User).where(
                and_(User.id == uid, User.deleted_at.is_(None))
            )
        )
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        result = await self.db.execute(
            select(User).where(
                and_(User.email == email.lower(), User.deleted_at.is_(None))
            )
        )
        return result.scalar_one_or_none()

    async def get_all(self, skip: int = 0, limit: int = 100) -> Sequence[User]:
        result = await self.db.execute(
            select(User)
            .where(User.deleted_at.is_(None))
            .offset(skip)
            .limit(limit)
            .order_by(User.created_at.desc())
        )
        return result.scalars().all()

    async def count(self) -> int:
        from sqlalchemy import func as sa_func
        result = await self.db.execute(
            select(sa_func.count())
            .select_from(User)
            .where(User.deleted_at.is_(None))
        )
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
        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def update_password(self, user: User, new_hash: str) -> User:
        user.password_hash = new_hash
        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def update_avatar(self, user: User, avatar_url: str) -> User:
        """Update the avatar_url field on a user record."""
        user.avatar_url = avatar_url
        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def soft_delete(self, user: User) -> None:
        """Soft delete: sets is_deleted=True."""
        from datetime import datetime, timezone
        user.is_deleted = True
        user.deleted_at = datetime.now(timezone.utc)
        await self.db.flush()
