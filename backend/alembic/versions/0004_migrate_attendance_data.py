"""Migrate attendance_records data to new attendance table.

This migration creates sessions from existing attendance_records data
and migrates attendance data to the new attendance table.

IMPORTANT: The legacy attendance_records table is kept for backward
compatibility with the Flutter app. Only new attendance should use
the new attendance table.

Revision ID: 0004
Revises: 0003
Create Date: 2026-03-19
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers
revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. Create sessions from existing attendance_records ───────────────────
    # For each unique (class_id, date) combination, create a session
    op.execute(
        """
        INSERT INTO sessions (id, classroom_id, session_date, start_time, status, created_at)
        SELECT
            gen_random_uuid(),
            ar.class_id,
            DATE(ar.checkin_time),
            MIN(ar.checkin_time)::TIME,
            'closed',
            MIN(ar.sync_time)
        FROM attendance_records ar
        WHERE ar.class_id IS NOT NULL
          AND ar.checkin_time IS NOT NULL
        GROUP BY ar.class_id, DATE(ar.checkin_time)
        ON CONFLICT DO NOTHING;
        """
    )

    # ── 2. Migrate attendance data ─────────────────────────────────────────────
    # Map attendance_records to the new attendance table
    op.execute(
        """
        INSERT INTO attendance (id, session_id, student_id, checkin_time, status, confidence, created_at)
        SELECT
            ar.id,
            s.id as session_id,
            ar.student_id,
            ar.checkin_time,
            ar.status,
            ar.confidence,
            ar.sync_time
        FROM attendance_records ar
        INNER JOIN sessions s ON s.classroom_id = ar.class_id
            AND s.session_date = DATE(ar.checkin_time)
        WHERE ar.class_id IS NOT NULL
          AND ar.checkin_time IS NOT NULL
        ON CONFLICT (session_id, student_id) DO NOTHING;
        """
    )

    # ── 3. Mark legacy table ───────────────────────────────────────────────────
    op.execute(
        "COMMENT ON TABLE attendance_records IS 'LEGACY TABLE - Data has been migrated to attendance table. Use attendance instead for new records.'"
    )


def downgrade() -> None:
    # Data migration is one-way - we don't delete the migrated data
    # Just remove the comment
    op.execute("COMMENT ON TABLE attendance_records IS NULL")
