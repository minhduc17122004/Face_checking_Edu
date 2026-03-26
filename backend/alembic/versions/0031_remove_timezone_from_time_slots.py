"""Remove timezone from time_slots start_time and end_time columns.

Revision ID: 0031_remove_timezone_from_time_slots
Revises: 0030_finalize_phase9
Create Date: 2026-03-26

Change time_slots.start_time and time_slots.end_time from
TIME WITH TIME ZONE to TIME (without timezone).
Flask/Flutter sends naive time strings like "01:00:00" which
PostgreSQL TIME WITH TIME ZONE cannot accept.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0031_remove_timezone_from_time_slots"
down_revision: Union[str, None] = "0030_finalize_phase9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Convert TIME WITH TIME ZONE → TIME (without timezone)
    # USING expression strips any timezone info and converts to plain TIME
    op.alter_column(
        "time_slots",
        "start_time",
        type_=sa.Time(),
        postgresql_using="start_time::time",
    )
    op.alter_column(
        "time_slots",
        "end_time",
        type_=sa.Time(),
        postgresql_using="end_time::time",
    )


def downgrade() -> None:
    # Revert TIME → TIME WITH TIME ZONE
    op.alter_column(
        "time_slots",
        "start_time",
        type_=sa.Time(timezone=True),
        postgresql_using="start_time",
    )
    op.alter_column(
        "time_slots",
        "end_time",
        type_=sa.Time(timezone=True),
        postgresql_using="end_time",
    )
