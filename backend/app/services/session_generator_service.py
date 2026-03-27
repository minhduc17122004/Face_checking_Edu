from __future__ import annotations
"""Session generator service — auto-generate attendance sessions from schedules."""
import uuid
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.session import Session
from app.models.schedule import Schedule
from app.models.course import Course
from app.models.time_slot import TimeSlot

# Vietnam timezone: UTC+7
VIETNAM_TZ = timezone(timedelta(hours=7))


class SessionGeneratorService:
    """Auto-generate attendance sessions for a given date from weekly schedules.

    For each active schedule that falls on the target date's day_of_week:
    1. Compute start_time = target_date + time_slot.start_time
    2. Compute end_time   = target_date + time_slot.end_time
    3. Apply attendance window from course config:
       - preset:   checkin_window = [slot_start, slot_end]
       - flexible: window = NULL  (teacher opens/closes manually)
       - custom:   window_start = slot_start + before_minutes
                   window_end   = window_start + after_minutes  (capped at slot_end)
    4. Check if session already exists for (schedule_id, date)
    5. If not exists → create
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def generate_sessions_for_date(self, target_date: date) -> list[Session]:
        """Main entry point — generates sessions for a single date."""
        day_of_week = target_date.isoweekday()  # 1=Monday ... 7=Sunday

        result = await self.db.execute(
            select(Schedule).where(
                and_(
                    Schedule.day_of_week == day_of_week,
                    Schedule.deleted_at.is_(None),
                )
            )
        )
        schedules = result.scalars().all()

        created: list[Session] = []

        # Use the already active transaction from get_db dependency
        for schedule in schedules:
            course_result = await self.db.execute(
                select(Course).where(
                    and_(
                        Course.id == schedule.course_id,
                        Course.deleted_at.is_(None),
                    )
                )
            )
            course = course_result.scalar_one_or_none()
            if not course:
                continue

            slot_result = await self.db.execute(
                select(TimeSlot).where(TimeSlot.id == schedule.time_slot_id)
            )
            time_slot = slot_result.scalar_one_or_none()
            if not time_slot:
                continue

            existing_result = await self.db.execute(
                select(Session).where(
                    and_(
                        Session.schedule_id == schedule.id,
                        Session.session_date == target_date,
                        Session.deleted_at.is_(None),
                    )
                )
            )
            if existing_result.scalar_one_or_none():
                continue

            session_start = self._combine_date_time(target_date, time_slot.start_time)
            session_end = self._combine_date_time(target_date, time_slot.end_time)

            checkin_window_start, checkin_window_end = self._compute_checkin_window(
                course, session_start, session_end
            )

            session = Session(
                course_id=course.id,
                schedule_id=schedule.id,
                session_date=target_date,
                start_time=session_start,
                end_time=session_end,
                checkin_window_start=checkin_window_start,
                checkin_window_end=checkin_window_end,
                status="scheduled",
            )
            self.db.add(session)
            created.append(session)

        if created:
            await self.db.flush()

        return created

    def _combine_date_time(self, d: date, t: time) -> datetime:
        """Combine date + time into timezone-aware datetime (Vietnam UTC+7)."""
        naive = datetime.combine(d, t)
        # time_slot times are stored as naive (no tz) — they represent Vietnam local time
        return naive.replace(tzinfo=VIETNAM_TZ)

    def _compute_checkin_window(
        self, course: Course, session_start: datetime, session_end: datetime
    ) -> tuple[datetime | None, datetime | None]:
        """Compute checkin window based on course attendance mode.

        Modes:
          preset  — window = [session_start, session_end]  (auto open/close at slot boundaries)
          flexible — window = None (teacher manually opens/closes)
          custom  — custom_window_start_minutes = offset from slot START to open (minutes)
                    custom_window_end_minutes   = offset from slot START to close (minutes)
                    → window_start = session_start + start_minutes
                    → window_end   = session_start + end_minutes
                    Clamped so window_end <= session_end.
        """
        mode = getattr(course, "attendance_mode", "preset") or "preset"

        if mode == "flexible":
            return None, None

        start_min = getattr(course, "custom_window_start_minutes", 0) or 0
        end_min = getattr(course, "custom_window_end_minutes", 30) or 30

        if mode == "custom":
            # Open the window `start_min` minutes after the slot starts
            window_start = session_start + timedelta(minutes=start_min)
            # Close the window `end_min` minutes after the slot starts (not past slot end)
            window_end = session_start + timedelta(minutes=end_min)
            if window_end > session_end:
                window_end = session_end
            return window_start, window_end

        # mode == "preset": open at slot start, close at slot end
        return session_start, session_end
