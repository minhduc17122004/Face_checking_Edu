@echo off
echo === Stopping API container to close DB connections...
docker compose stop api > clean_restore.log 2>&1

echo === Recreating database vedura_db...
docker compose exec -T db psql -U vedura -d postgres -c "DROP DATABASE IF EXISTS vedura_db WITH (FORCE);" >> clean_restore.log 2>&1
docker compose exec -T db psql -U vedura -d postgres -c "CREATE DATABASE vedura_db OWNER vedura;" >> clean_restore.log 2>&1

echo === Restoring from last_backup.sql...
docker compose exec -T db psql -U vedura -d vedura_db < backups\last_backup.sql >> clean_restore.log 2>&1

echo === Starting API container...
docker compose start api >> clean_restore.log 2>&1

echo === Running Alembic Migrations...
docker compose exec -T api alembic upgrade head >> clean_restore.log 2>&1

echo === Done! Check clean_restore.log for details.
