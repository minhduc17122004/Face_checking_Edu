import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
import os

DATABASE_URL = "postgresql+asyncpg://vedura:vedura_pass@localhost:5432/vedura_db"

async def check():
    engine = create_async_engine(DATABASE_URL)
    try:
        async with engine.connect() as conn:
            result = await conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'courses'"))
            columns = [row[0] for row in result]
            print(f"Columns in 'courses': {columns}")
            
            if 'course_start_date' in columns and 'course_end_date' in columns:
                print("SUCCESS: Migration applied correctly.")
            else:
                print("FAILURE: Columns missing.")
    except Exception as e:
        print(f"ERROR: {e}")
    finally:
        await engine.dispose()

if __name__ == "__main__":
    asyncio.run(check())
