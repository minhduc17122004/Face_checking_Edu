from __future__ import annotations
"""RefreshToken model — stores JWT refresh tokens in the database."""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import String, Boolean, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class RefreshToken(Base):
    """Stores hashed refresh tokens for revocation support.

    Each refresh token is identified by its JWT jti claim.
    Tokens are hashed before storage to prevent leakage if the DB is compromised.
    """

    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Hashed value of the JWT refresh token (jti claim)
    token_jti: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    # Optional device identifier for multi-device management
    device_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    # Token expiration
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    # Revocation flag
    revoked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    # Token metadata
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=_utc_now,
    )

    def __repr__(self) -> str:
        return f"<RefreshToken id={self.id} user_id={self.user_id} revoked={self.revoked}>"
