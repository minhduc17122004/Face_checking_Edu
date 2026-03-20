from __future__ import annotations
"""RefreshToken model — stores JWT refresh tokens in the database."""
import uuid
from datetime import datetime, timezone
from typing import Optional, TYPE_CHECKING

from sqlalchemy import String, Boolean, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User


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
    token_jti: Mapped[str] = mapped_column(
        String(64), nullable=False, unique=True, index=True
    )

    # Optional device identifier for multi-device management
    device_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Device info metadata (browser, OS, etc.)
    device_info: Mapped[Optional[dict]] = mapped_column(
        JSONB, nullable=True
    )

    # Token expiration
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    # Revocation flag
    revoked: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )

    # Token metadata
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=_utc_now,
    )

    # ── Relationships ──────────────────────────────────────────
    user: Mapped["User"] = relationship(
        "User",
        back_populates="refresh_tokens",
    )

    @property
    def is_expired(self) -> bool:
        """Check if token is expired."""
        return datetime.now(timezone.utc) > self.expires_at

    @property
    def is_valid(self) -> bool:
        """Check if token is valid (not expired and not revoked)."""
        return not self.revoked and not self.is_expired

    def __repr__(self) -> str:
        return f"<RefreshToken id={self.id} user_id={self.user_id} revoked={self.revoked}>"
