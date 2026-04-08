import asyncio
from sqlalchemy import select, and_
from sqlalchemy.orm import joinedload
from app.core.database import SessionLocal
from app.models.session import Session
from app.models.course import Course as CourseModel
import uuid
from datetime import datetime, timezone

async def test():
    async with SessionLocal() as db:
        room_id = 'd7e7c387-5acf-4e4d-b06b-a23467983191'
        print(f"Testing room: {room_id}")
        
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
        start_of_day = datetime.combine(today, datetime.min.time(), tzinfo=timezone.utc)
        end_of_day = datetime.combine(today, datetime.max.time(), tzinfo=timezone.utc)

        try:
            active_q = await db.execute(
                select(Session)
                .options(
                    joinedload(Session.course),
                    joinedload(Session.attendance_config),
                )
                .where(
                    and_(
                        Session.course_id.in_(select(course_subq)),
                        Session.start_time >= start_of_day,
                        Session.start_time <= end_of_day,
                        Session.deleted_at.is_(None),
                    )
                )
                .order_by(Session.start_time.asc())
            )
            sessions = active_q.unique().scalars().all()
            print(f"Found {len(sessions)} sessions")
            for s in sessions:
                print(s.id)
        except Exception as e:
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test())
