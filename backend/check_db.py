import asyncio
from sqlalchemy import create_task_context
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import inspect
import os

DATABASE_URL = "postgresql+asyncpg://vedura:vedura_pass@localhost:5432/vedura_db"

async def check():
    engine = create_async_engine(DATABASE_URL)
    async with engine.connect() as conn:
        def get_cols(connection):
            from sqlalchemy import inspect
            inspector = inspect(connection)
            return inspector.get_columns("courses")
        
        columns = await conn.run_sync(get_cols)
        for col in columns:
            print(f"Column: {col['name']}")
    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(check())
