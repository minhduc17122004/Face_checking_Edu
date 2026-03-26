import asyncio
import sys
import os
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

# Manually specify the URL because we are running from host (localhost) 
# while the app config uses 'db' (docker service name)
DATABASE_URL = "postgresql+asyncpg://vedura:vedura_pass@localhost:5432/vedura_db"

async def delete_all_device_requests():
    print(f"Connecting to database at {DATABASE_URL}...")
    try:
        engine = create_async_engine(DATABASE_URL)
        async with engine.begin() as conn:
            await conn.execute(text("DELETE FROM device_requests"))
        print("SUCCESS: Deleted all device requests.")
        await engine.dispose()
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    asyncio.run(delete_all_device_requests())
