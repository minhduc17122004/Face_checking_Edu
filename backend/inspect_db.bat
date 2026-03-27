@echo off
set PGPASSWORD=vedura_pass
echo CURRENT ALEMBIC VERSION... > columns.log 2>&1
docker compose exec -T db psql -U vedura -d vedura_db -c "SELECT version_num FROM alembic_version;" >> columns.log 2>&1
echo COLUMNS FOR courses... >> columns.log 2>&1
docker compose exec -T db psql -U vedura -d vedura_db -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'courses';" >> columns.log 2>&1
echo RECENT SESSIONS... >> columns.log 2>&1
docker compose exec -T db psql -U vedura -d vedura_db -c "SELECT id, status FROM sessions LIMIT 5;" >> columns.log 2>&1
