docker compose exec -T api alembic upgrade head > migration_restore.log 2>&1
