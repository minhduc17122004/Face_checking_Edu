from __future__ import annotations
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import Boolean, DateTime
from sqlalchemy.orm import Mapped, mapped_column


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class SoftDeleteMixin:
    """Adds is_deleted + deleted_at to any SQLAlchemy model.

    All queries against models using this mixin should filter
    is_deleted == False by default (enforced in BaseRepository).
    """

    is_deleted: Mapped[bool] = mapped_column(Boolean(), default=False, nullable=False)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)


class AuditMixin:
    """Adds created_by + updated_by audit trail to any SQLAlchemy model."""

    created_by: Mapped[Optional[str]] = None  # Set to UUID string at runtime
    updated_by: Mapped[Optional[str]] = None
