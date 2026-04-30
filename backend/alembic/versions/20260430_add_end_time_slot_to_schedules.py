"""add end_time_slot_id to schedules

Revision ID: 20260430_end_slot
Revises: 20260419_add_is_spoof
Create Date: 2026-04-30 00:45:00

Adds end_time_slot_id column (nullable FK → time_slots.id) to the
schedules table so that a single Schedule record can represent a
multi-period block (e.g. periods 1-3).
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers
revision = "add_end_time_slot"
down_revision = "add_is_spoof"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "schedules",
        sa.Column(
            "end_time_slot_id",
            sa.Integer(),
            sa.ForeignKey("time_slots.id", name="fk_schedule_end_time_slot"),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_schedules_end_time_slot_id",
        "schedules",
        ["end_time_slot_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_schedules_end_time_slot_id", table_name="schedules")
    op.drop_column("schedules", "end_time_slot_id")
