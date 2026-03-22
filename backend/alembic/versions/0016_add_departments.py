"""Add departments table.

Revision ID: 0016_add_departments
Revises: 0015_fix_naming_inconsistency
Create Date: 2026-03-21

Changes:
1. Create departments table (id, code UNIQUE, name, description, timestamps, soft-delete)
2. Create ix_departments_code unique index
3. Create ix_departments_name index
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0016_add_departments"
down_revision: Union[str, None] = "123456789abc"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _table_exists(table: str) -> bool:
    return f"""
        SELECT 1 FROM information_schema.tables
        WHERE table_name = '{table}'
    """


def _column_exists(table: str, column: str) -> bool:
    return f"""
        SELECT 1 FROM information_schema.columns
        WHERE table_name = '{table}' AND column_name = '{column}'
    """


def upgrade() -> None:
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _table_exists("departments") + """) THEN
                CREATE TABLE departments (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    code VARCHAR(50) NOT NULL UNIQUE,
                    name VARCHAR(255) NOT NULL,
                    description VARCHAR(500),
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    deleted_at TIMESTAMP WITH TIME ZONE,
                    created_by UUID,
                    updated_by UUID
                );
            END IF;
        END $$;
    """)

    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes WHERE indexname = 'ix_departments_code'
            ) THEN
                CREATE UNIQUE INDEX ix_departments_code ON departments(code);
            END IF;
        END $$;
    """)

    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes WHERE indexname = 'ix_departments_name'
            ) THEN
                CREATE INDEX ix_departments_name ON departments(name);
            END IF;
        END $$;
    """)

    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes WHERE tablename = 'departments'
                  AND indexname = 'ix_departments_deleted_at'
            ) THEN
                CREATE INDEX ix_departments_deleted_at ON departments(deleted_at);
            END IF;
        END $$;
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_departments_code")
    op.execute("DROP INDEX IF EXISTS ix_departments_name")
    op.execute("DROP INDEX IF EXISTS ix_departments_deleted_at")
    op.execute("DROP TABLE IF EXISTS departments")
