import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select
from app.models.course import Course
import os
import sys

# Add current directory to path for imports
sys.path.append(os.getcwd())

DATABASE_URL = "postgresql+asyncpg://vedura:vedura_pass@localhost:5432/vedura_db"

async def test_fetch():
    engine = create_async_engine(DATABASE_URL)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        try:
            print("Fetching courses...")
            result = await session.execute(select(Course))
            courses = result.scalars().all()
            print(f"Success! Found {len(courses)} courses.")
            for c in courses[:2]:
                print(f"- Course: {c.course_name}")
        except Exception as e:
            print(f"ERROR: {e}")
            import traceback
            traceback.print_exc()
    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(test_fetch())
