@echo off
set PGPASSWORD=vedura_pass
echo CLEANING UP PHASE 9 TABLES... > cleanup.log 2>&1
docker compose exec -T db psql -U vedura -d vedura_db -c "DROP TABLE IF EXISTS attendance_audit_logs CASCADE;" >> cleanup.log 2>&1
docker compose exec -T db psql -U vedura -d vedura_db -c "DROP TABLE IF EXISTS device_requests CASCADE;" >> cleanup.log 2>&1
docker compose exec -T db psql -U vedura -d vedura_db -c "DROP TABLE IF EXISTS attendance_configs CASCADE;" >> cleanup.log 2>&1
echo DONE. >> cleanup.log 2>&1
