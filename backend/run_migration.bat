@echo off
set PGPASSWORD=vedura_pass
set DATABASE_URL=postgresql+asyncpg://vedura:vedura_pass@127.0.0.1:5432/vedura_db

echo STARTING BACKUP... > migration_final.log 2>&1
if not exist backups mkdir backups
docker-compose exec -T db pg_dump -U vedura -d vedura_db > backups\last_backup.sql 2>> migration_final.log

echo STARTING UPGRADE... >> migration_final.log 2>&1
call .venv\Scripts\alembic.exe upgrade head >> migration_final.log 2>&1
echo FINISHED. >> migration_final.log 2>&1
