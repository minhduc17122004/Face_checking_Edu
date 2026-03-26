import asyncio
from datetime import datetime, timezone
from sqlalchemy import select, and_
from sqlalchemy.orm import joinedload
from app.core.database import SessionLocal
from app.models.session import Session
from app.models.course import Course as CourseModel

async def test():
    async with SessionLocal() as db:
        room_id = 'd7e7c387-5acf-4e4d-b06b-a23467983191'
        
        course_subq = (
            select(CourseModel.id)
            .where(
                and_(
                    CourseModel.room_id == room_id,
                    CourseModel.deleted_at.is_(None),
                )
            )
            .subquery()
        )
        
        now_utc = datetime.now(timezone.utc)
        today = now_utc.date()
        today_vt = datetime.fromisoformat('2026-03-26').date()
        print('today =', today)
        
        active_q = await db.execute(
            select(Session)
            .options(
                joinedload(Session.course)
            )
            .where(
                and_(
                    Session.course_id.in_(select(course_subq)),
                    Session.session_date == today_vt,
                    Session.status != "closed",
                    Session.deleted_at.is_(None),
                )
            )
        )
        sessions = active_q.scalars().all()
        print(f"Found {len(sessions)} sessions")
        for s in sessions:
            print(f"- id={s.id}, name={s.course.course_name}, status={s.status}, end_time={s.end_time}")

asyncio.run(test())
