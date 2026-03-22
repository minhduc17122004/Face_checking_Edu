@echo off
docker compose exec -T db pg_dump -U vedura -d vedura_db > backups\backup_vedura_db_20260321_rename_employee.sql
echo Backup complete.
