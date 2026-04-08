"""Refactor teachers table — add department_id FK, migrate department string.

Revision ID: 0017_refactor_teachers_dept
Revises: 0016_add_departments
Create Date: 2026-03-21

Changes:
1. Add department_id (UUID FK) to teachers table
2. Copy existing department string values → departments table
3. Update teachers.department_id with new department.id
4. Remove teachers.department (string column)
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0017_refactor_teachers_dept"
down_revision: Union[str, None] = "0016_add_departments"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(table: str, column: str) -> bool:
    return f"""
        SELECT 1 FROM information_schema.columns
        WHERE table_name = '{table}' AND column_name = '{column}'
    """


def _table_exists(table: str) -> bool:
    return f"""
        SELECT 1 FROM information_schema.tables
        WHERE table_name = '{table}'
    """


def upgrade() -> None:
    # 1. Add department_id column (nullable first, FK after data migration)
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("teachers", "department_id") + """) THEN
                ALTER TABLE teachers ADD COLUMN department_id UUID;
            END IF;
        END $$;
    """)

    # 2. Create index on department_id
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes
                WHERE tablename = 'teachers' AND indexname = 'ix_teachers_department_id'
            ) THEN
                CREATE INDEX ix_teachers_department_id ON teachers(department_id);
            END IF;
        END $$;
    """)

    # 3. Create departments for each unique department string value
    op.execute("""
        DO $$
        DECLARE
            dept_code TEXT;
            dept_name TEXT;
            dept_id UUID;
        BEGIN
            -- For each unique non-null department string in teachers
            FOR dept_code, dept_name IN
                SELECT DISTINCT department, department
                FROM teachers
                WHERE department IS NOT NULL AND department != ''
            LOOP
                -- Check if department already exists by name
                SELECT id INTO dept_id FROM departments WHERE name = dept_name LIMIT 1;

                -- If not exists, create it
                IF dept_id IS NULL THEN
                    dept_id := gen_random_uuid();
                    INSERT INTO departments (id, code, name, created_at, updated_at)
                    VALUES (dept_id, 'DEPT_' || initcap(replace(dept_code, ' ', '_')),
                            dept_name, NOW(), NOW())
                    ON CONFLICT (code) DO NOTHING;
                END IF;

                -- Update teachers with department_id
                UPDATE teachers
                SET department_id = (
                    SELECT id FROM departments WHERE name = dept_name LIMIT 1
                )
                WHERE department = dept_name AND department_id IS NULL;
            END LOOP;
        END $$;
    """)

    # 4. Add FK constraint
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'fk_teachers_department'
            ) THEN
                ALTER TABLE teachers
                ADD CONSTRAINT fk_teachers_department
                FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL;
            END IF;
        END $$;
    """)

    # 5. Remove teachers.department string column
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("teachers", "department") + """) THEN
                ALTER TABLE teachers DROP COLUMN IF EXISTS department;
            END IF;
        END $$;
    """)


def downgrade() -> None:
    # 1. Add back department string column
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("teachers", "department") + """) THEN
                ALTER TABLE teachers ADD COLUMN department VARCHAR(255);
            END IF;
        END $$;
    """)

    # 2. Copy department names back from FK
    op.execute("""
        UPDATE teachers t
        SET department = d.name
        FROM departments d
        WHERE t.department_id = d.id;
    """)

    # 3. Remove FK constraint
    op.execute("DROP CONSTRAINT IF EXISTS fk_teachers_department")

    # 4. Remove department_id column
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("teachers", "department_id") + """) THEN
                ALTER TABLE teachers DROP COLUMN IF EXISTS department_id;
            END IF;
        END $$;
    """)
