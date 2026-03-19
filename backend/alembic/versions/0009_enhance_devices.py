"""Add device fields for anti-cheat and soft delete.

Adds:
- device_type
- ip_address
- last_active_at
- is_deleted, deleted_at

Revision ID: 0009
Revises: 0008
Create Date: 2026-03-19
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0009"
down_revision: Union[str, None] = "0008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Anti-cheat fields (updated_at was already in initial schema)
    op.add_column(
        "devices",
        sa.Column("last_active_at", sa.DateTime(timezone=True), nullable=True),
    )
    # device_type already exists in initial schema, skip adding it
    op.add_column(
        "devices",
        sa.Column("ip_address", sa.String(45), nullable=True),
    )

    # Soft delete fields
    op.add_column(
        "devices",
        sa.Column("is_deleted", sa.Boolean, default=False, nullable=False),
    )
    op.add_column(
        "devices",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("idx_devices_is_deleted", "devices", ["is_deleted"])

    # Add is_active, user_id, device_id, is_deleted to face_embeddings
    op.add_column(
        "face_embeddings",
        sa.Column(
            "user_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.add_column(
        "face_embeddings",
        sa.Column(
            "device_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("devices.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.add_column(
        "face_embeddings",
        sa.Column("is_active", sa.Boolean, default=True, nullable=False),
    )
    op.create_index("idx_face_embeddings_user", "face_embeddings", ["user_id"])
    op.create_index("idx_face_embeddings_device", "face_embeddings", ["device_id"])


def downgrade() -> None:
    # Drop face_embeddings indexes and columns
    op.drop_index("idx_face_embeddings_device", table_name="face_embeddings")
    op.drop_index("idx_face_embeddings_user", table_name="face_embeddings")
    op.drop_column("face_embeddings", "is_active")
    op.drop_column("face_embeddings", "device_id")
    op.drop_column("face_embeddings", "user_id")

    # Drop devices soft delete and anti-cheat fields (updated_at and device_type were already in initial schema)
    op.drop_index("idx_devices_is_deleted", table_name="devices")
    op.drop_column("devices", "deleted_at")
    op.drop_column("devices", "is_deleted")
    op.drop_column("devices", "ip_address")
    op.drop_column("devices", "last_active_at")
