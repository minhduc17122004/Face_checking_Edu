@echo off
set PGPASSWORD=vedura_pass
set DATABASE_URL=postgresql+asyncpg://vedura:vedura_pass@127.0.0.1:5432/vedura_db
echo CURRENT VERSION... > current_ver.log 2>&1
docker compose exec -T api alembic current >> current_ver.log 2>&1
echo DONE. >> current_ver.log 2>&1
