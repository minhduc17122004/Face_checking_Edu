from __future__ import annotations
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession


class BaseService:
    """Base service with shared db session and optional audit user_id.

    Subclasses should inject repositories that also share the same db session.
    """

    def __init__(self, db: AsyncSession, user_id: str | None = None) -> None:
        self.db: AsyncSession = db
        self.user_id: str | None = user_id  # for audit trail in created_by / updated_by
