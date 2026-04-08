@echo off
echo === Waiting for database to be ready...
timeout /t 5

echo === Recreating database vedura_db...
docker compose exec -T db psql -U vedura -d postgres -c "DROP DATABASE IF EXISTS vedura_db;" > restore.log 2>&1
docker compose exec -T db psql -U vedura -d postgres -c "CREATE DATABASE vedura_db OWNER vedura;" >> restore.log 2>&1

echo === Restoring from last_backup.sql...
docker compose exec -T db psql -U vedura -d vedura_db < backups\last_backup.sql >> restore.log 2>&1

echo === Done! Check restore.log for details.
