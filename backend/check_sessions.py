import asyncio
from app.core.database import AsyncSessionLocal
from sqlalchemy import select
from app.models.session import Session

async def main():
    async with AsyncSessionLocal() as db:
        res = await db.execute(select(Session))
        sessions = res.scalars().all()
        for s in sessions:
            print(f"Session: {s.id}, Course: {s.course_id}, Status: {s.status}, Date: {s.session_date}")

if __name__ == "__main__":
    asyncio.run(main())
