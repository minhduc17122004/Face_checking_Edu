@echo off
set PGPASSWORD=vedura_pass
set DATABASE_URL=postgresql+asyncpg://vedura:vedura_pass@127.0.0.1:5432/vedura_db

echo DROPPING problematic table... > final_migration.log 2>&1
docker compose exec -T db psql -U vedura -d vedura_db -c "DROP TABLE IF EXISTS attendance_audit_logs CASCADE;" >> final_migration.log 2>&1

echo UPGRADING... >> final_migration.log 2>&1
docker compose exec -T api alembic upgrade head >> final_migration.log 2>&1
echo DONE. >> final_migration.log 2>&1
