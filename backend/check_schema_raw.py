import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
import os

DATABASE_URL = "postgresql+asyncpg://vedura:vedura_pass@localhost:5432/vedura_db"

async def check():
    engine = create_async_engine(DATABASE_URL)
    async with engine.connect() as conn:
        print("Checking tables...")
        result = await conn.execute(text("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"))
        for row in result:
            print(f"Table: {row[0]}")
            
        print("\nChecking columns for 'courses'...")
        result = await conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'courses'"))
        found = False
        for row in result:
            print(f"Column: {row[0]}")
            found = True
        if not found:
            print("Table 'courses' not found!")
            
    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(check())
