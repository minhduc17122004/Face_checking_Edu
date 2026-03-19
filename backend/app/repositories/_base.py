from __future__ import annotations
from typing import Any, Generic, TypeVar

from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import Base

ModelT = TypeVar("ModelT", bound=Base)


class BaseRepository(Generic[ModelT]):
    """Base async repository with soft-delete filtering.

    All subclasses automatically exclude soft-deleted records from queries.
    Inherit from this class and set `model` to get:
    - get_by_id() with soft-delete filter
    - list() with soft-delete filter and pagination
    - count() with soft-delete filter
    - soft_delete() — sets is_deleted=True, deleted_at=now
    """

    model: type[Base] = Base  # Override in subclass

    def __init__(self, db: AsyncSession) -> None:
        self.db: AsyncSession = db

    # ── Soft-delete helpers ──────────────────────────────────────────────────────
    @staticmethod
    def _active(stmt) -> Any:
        """Append is_deleted=False filter to any select statement."""
        return stmt.where(getattr(BaseRepository.model, "is_deleted") == False)  # noqa: E501, E714

    # ── Read ────────────────────────────────────────────────────────────────────
    async def get_by_id(self, id: Any) -> ModelT | None:
        stmt = select(self.model).where(self.model.id == id)
        result = await self.db.execute(self._active(stmt))
        return result.scalar_one_or_none()

    async def list(self, skip: int = 0, limit: int = 100) -> tuple[list[ModelT], int]:
        """Return (items, total_count) with soft-delete filtering."""
        count_stmt = select(func.count()).select_from(self.model)
        total = (await self.db.execute(self._active(count_stmt))).scalar_one()

        data_stmt = (
            select(self.model)
            .offset(skip)
            .limit(limit)
            .order_by(self.model.created_at.desc())
        )
        result = await self.db.execute(self._active(data_stmt))
        return list(result.scalars().all()), total

    async def count(self) -> int:
        stmt = select(func.count()).select_from(self.model)
        result = await self.db.execute(self._active(stmt))
        return result.scalar_one()

    # ── Write ────────────────────────────────────────────────────────────────────
    async def add(self, instance: ModelT) -> ModelT:
        """Add and flush a model instance."""
        self.db.add(instance)
        await self.db.flush()
        await self.db.refresh(instance)
        return instance

    async def soft_delete(self, instance: ModelT) -> None:
        """Set is_deleted=True instead of hard delete."""
        from datetime import datetime, timezone
        instance.is_deleted = True
        instance.deleted_at = datetime.now(timezone.utc)
        await self.db.flush()
