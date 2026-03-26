@echo off
set PGPASSWORD=vedura_pass
echo COLUMNS FOR devices... > columns.log 2>&1
docker compose exec -T db psql -U vedura -d vedura_db -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'devices';" >> columns.log 2>&1
echo COLUMNS FOR attendance... >> columns.log 2>&1
docker compose exec -T db psql -U vedura -d vedura_db -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'attendance';" >> columns.log 2>&1
echo TABLES LIST... >> columns.log 2>&1
docker compose exec -T db psql -U vedura -d vedura_db -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';" >> columns.log 2>&1
