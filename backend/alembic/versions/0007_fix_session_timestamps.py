"""Fix session to use TIMESTAMP instead of TIME.

Migrates:
- session_date (DATE) + start_time (TIME) -> start_time (TIMESTAMP)
- end_time (TIME) -> end_time (TIMESTAMP)
- Adds checkin_start_time, checkin_end_time

Revision ID: 0007
Revises: 0006
Create Date: 2026-03-19
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0007"
down_revision: Union[str, None] = "0006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add new TIMESTAMP columns (nullable first for data migration)
    op.add_column(
        "sessions",
        sa.Column(
            "start_time_new",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
    )
    op.add_column(
        "sessions",
        sa.Column("end_time_new", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "sessions",
        sa.Column(
            "checkin_start_time", sa.DateTime(timezone=True), nullable=True
        ),
    )
    op.add_column(
        "sessions",
        sa.Column("checkin_end_time", sa.DateTime(timezone=True), nullable=True),
    )

    # Migrate existing data: combine session_date + start_time into full timestamp
    # First, ensure timezone is set to UTC for consistency
    op.execute("SET TIME ZONE 'UTC';")

    # Cast TIME to TEXT, then to INTERVAL, then add to DATE (cast to TIMESTAMPTZ)
    # The trick: start_time::text gives 'HH:MM:SS', which can be added to a timestamp
    op.execute("""
        UPDATE sessions
        SET start_time_new = (
            (session_date || ' 00:00:00')::timestamptz + start_time::text::interval
        )
        WHERE session_date IS NOT NULL AND start_time IS NOT NULL
    """)
    op.execute("""
        UPDATE sessions
        SET end_time_new = (
            (session_date || ' 00:00:00')::timestamptz + end_time::text::interval
        )
        WHERE session_date IS NOT NULL AND end_time IS NOT NULL
    """)

    # Drop old columns
    op.drop_column("sessions", "start_time")
    op.drop_column("sessions", "end_time")
    op.drop_column("sessions", "session_date")

    # Rename new columns to final names
    op.alter_column(
        "sessions", "start_time_new", new_column_name="start_time", nullable=False
    )
    op.alter_column("sessions", "end_time_new", new_column_name="end_time")


def downgrade() -> None:
    # Add back old columns
    op.add_column(
        "sessions",
        sa.Column("session_date", sa.Date(), nullable=False),
    )
    op.add_column(
        "sessions",
        sa.Column("start_time", sa.Time(timezone=True), nullable=False),
    )
    op.add_column(
        "sessions",
        sa.Column("end_time", sa.Time(timezone=True), nullable=True),
    )

    # Extract date and time portions from timestamps
    op.execute("UPDATE sessions SET session_date = start_time::date")
    op.execute("UPDATE sessions SET start_time = start_time::time")
    op.execute("UPDATE sessions SET end_time = end_time::time WHERE end_time IS NOT NULL")

    # Drop new columns
    op.drop_column("sessions", "checkin_start_time")
    op.drop_column("sessions", "checkin_end_time")
    op.drop_column("sessions", "end_time")
    op.drop_column("sessions", "start_time")
