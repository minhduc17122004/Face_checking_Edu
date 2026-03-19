"""Alembic async migration environment.

Configured for SQLAlchemy 2.x async engine (asyncpg driver).
Reads DATABASE_URL from environment so docker-compose / .env values
override the alembic.ini default.
"""
import asyncio
import os
import sys
from logging.config import fileConfig

# Add the project root (the directory containing `app/`) to sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context

# ── Alembic config ─────────────────────────────────────────────────────────
config = context.config

# Allow DATABASE_URL env variable to override alembic.ini
database_url = os.getenv("DATABASE_URL")
if database_url:
    config.set_main_option("sqlalchemy.url", database_url)

# Interpret the config file for Python logging setup
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# ── Create metadata from models ─────────────────────────────────────────────
# Import all models to register them with Base
import app.models  # noqa: F401
from app.core.database import Base

# Target metadata for --autogenerate support
target_metadata = Base.metadata


# ── Offline migrations (no DB connection) ──────────────────────────────────
def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    SQL statements are emitted to stdout / a file without connecting to the DB.
    Useful for generating SQL scripts to review before applying.
    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
        compare_server_default=True,
    )
    with context.begin_transaction():
        context.run_migrations()


# ── Online migrations (live DB connection) ─────────────────────────────────
def do_run_migrations(connection: Connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,
        compare_server_default=True,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Create an async engine and run migrations inside it."""
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode (default for `alembic upgrade head`)."""
    asyncio.run(run_async_migrations())


# ── Entry point ────────────────────────────────────────────────────────────
if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
