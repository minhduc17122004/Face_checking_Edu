#!/bin/sh
# entrypoint.sh — Run Alembic migrations then start the API server.
# This script is the container ENTRYPOINT so that every time the container
# starts (or restarts), the DB schema is guaranteed to be up-to-date.

set -e

echo "⏳  Waiting for database to be ready..."
# Simple retry loop — the docker-compose healthcheck on `db` ensures we
# get here only after pg_isready passes, but we add a small guard anyway.
until python -c "
import asyncio, asyncpg, os, sys
async def check():
    url = os.environ.get('DATABASE_URL','').replace('postgresql+asyncpg://','')
    try:
        conn = await asyncpg.connect('postgresql://' + url)
        await conn.close()
    except Exception as e:
        sys.exit(1)
asyncio.run(check())
" 2>/dev/null; do
    echo "   DB not ready yet — retrying in 2s..."
    sleep 2
done

echo "✅  Database is ready."
echo "🔄  Running Alembic migrations..."
alembic upgrade head
echo "✅  Migrations complete."

echo "🚀  Starting Vedura API server..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
