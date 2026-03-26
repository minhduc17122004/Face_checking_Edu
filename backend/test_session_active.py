import asyncio
from app.core.database import SessionLocal
from sqlalchemy import select, and_
from app.models.session import Session

async def test():
    async with SessionLocal() as db:
        res = await db.execute(select(Session).where(Session.course_name.like('thứ 6%')))
        s = res.scalars().first()
        if s:
            print('ID:', s.id)
            print('course_id:', s.course_id)
            print('status:', s.status)
            print('date:', s.session_date)
            from app.models.course import Course
            r = await db.execute(select(Course).where(Course.id == s.course_id))
            c = r.scalars().first()
            if c:
                print('Course room_id:', c.room_id)
        else:
            print('Not found')
asyncio.run(test())
