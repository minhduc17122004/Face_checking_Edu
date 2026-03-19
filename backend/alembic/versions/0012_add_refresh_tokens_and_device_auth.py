"""Add refresh_tokens table and device authentication fields.

Revision ID: 0012
Revises: 0011
Create Date: 2026-03-19
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0012"
down_revision: Union[str, None] = "0011"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. refresh_tokens table ────────────────────────────────────────────────
    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column(
            "user_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token_jti", sa.String(64), nullable=False),
        sa.Column("device_id", sa.String(255), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked", sa.Boolean, nullable=False, server_default="false"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_refresh_tokens_user_id", "refresh_tokens", ["user_id"])
    op.create_index("ix_refresh_tokens_token_jti", "refresh_tokens", ["token_jti"])

    # ── 2. Device authentication fields ─────────────────────────────────────
    # Add device_secret and api_key columns to devices table
    op.add_column(
        "devices",
        sa.Column(
            "device_secret",
            sa.String(255),
            nullable=True,
        ),
    )
    op.add_column(
        "devices",
        sa.Column(
            "api_key",
            sa.String(64),
            nullable=True,
            unique=True,
        ),
    )
    op.add_column(
        "devices",
        sa.Column(
            "last_token_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_index("ix_refresh_tokens_token_jti", table_name="refresh_tokens")
    op.drop_index("ix_refresh_tokens_user_id", table_name="refresh_tokens")
    op.drop_table("refresh_tokens")

    op.drop_column("devices", "last_token_at")
    op.drop_column("devices", "api_key")
    op.drop_column("devices", "device_secret")
