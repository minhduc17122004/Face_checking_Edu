from __future__ import annotations
"""Transaction utilities — context managers for safe DB transaction boundaries."""
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import AsyncSession


@asynccontextmanager
async def transaction(db: AsyncSession):
    """Transactional context manager for database operations.

    Usage:
        async with transaction(self.db):
            # all ops here are in one transaction
            await self.repo.create(...)
        # auto-commits on success, rolls back on any exception

    NOTE: Prefer this over raw db.begin() when the session is managed
    externally (e.g., via FastAPI Depends). Use db.begin() directly when
    you are the one creating/managing the session lifecycle.
    """
    try:
        yield
        await db.commit()
    except Exception:
        await db.rollback()
        raise
