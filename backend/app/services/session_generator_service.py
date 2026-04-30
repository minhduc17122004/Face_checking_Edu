from __future__ import annotations
"""Session generator service — auto-generate attendance sessions from schedules."""
import uuid
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.session import Session
from app.models.schedule import Schedule

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

    @staticmethod
    def _schedule_generation_options():
        return (
            joinedload(Schedule.course),
            joinedload(Schedule.time_slot),
            joinedload(Schedule.end_time_slot),
        )

    async def sync_sessions(self, sessions: list[Session]) -> int:
        """Repair existing session timing/window fields from their schedules."""
        updated = 0
        for session in sessions:
            if await self._sync_existing_session(session):
                updated += 1
        if updated:
            await self.db.flush()
        return updated

    async def generate_sessions_for_date(self, target_date: date) -> list[Session]:
        """Main entry point — generates sessions for a single date."""
        day_of_week = target_date.isoweekday()  # 1=Monday ... 7=Sunday

        result = await self.db.execute(
            select(Schedule)
            .options(*self._schedule_generation_options())
            .where(
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
            sessions = await self._generate_session_internal(schedule, target_date)
            created.extend(sessions)

        if created:
            await self.db.flush()

        return created

    async def generate_sessions_for_course_range(
        self, course_id: uuid.UUID, start_date: date, end_date: date
    ) -> list[Session]:
        """Generate sessions for a specific course within a date range."""
        from app.models.schedule import Schedule
        
        # Get all active schedules for the course
        result = await self.db.execute(
            select(Schedule)
            .options(*self._schedule_generation_options())
            .where(
                and_(
                    Schedule.course_id == course_id,
                    Schedule.deleted_at.is_(None),
                )
            )
        )
        schedules = result.scalars().all()
        
        created: list[Session] = []
        current_date = start_date
        while current_date <= end_date:
            day_of_week = current_date.isoweekday()
            for schedule in schedules:
                if schedule.day_of_week == day_of_week:
                    sessions = await self._generate_session_internal(schedule, current_date)
                    created.extend(sessions)
            current_date += timedelta(days=1)
            
        if created:
            await self.db.flush()
        return created

    async def _generate_session_internal(self, schedule: Schedule, target_date: date) -> list[Session]:
        """Internal helper to generate a session for a schedule and date."""
        course = schedule.course
        if not course:
            return []

        if course.deleted_at is not None:
            return []

        time_slot = schedule.time_slot
        if not time_slot:
            return []

        end_time_slot = schedule.end_time_slot or time_slot

        session_start = self._combine_date_time(target_date, time_slot.start_time)
        session_end = self._combine_date_time(target_date, end_time_slot.end_time)

        checkin_window_start, checkin_window_end = self._compute_checkin_window(
            course, session_start, session_end
        )

        existing_result = await self.db.execute(
            select(Session).where(
                and_(
                    Session.schedule_id == schedule.id,
                    Session.session_date == target_date,
                    Session.deleted_at.is_(None),
                )
            )
        )
        existing_session = existing_result.scalar_one_or_none()
        if existing_session is not None:
            self._apply_expected_session_fields(
                existing_session,
                session_date=target_date,
                session_start=session_start,
                session_end=session_end,
                checkin_window_start=checkin_window_start,
                checkin_window_end=checkin_window_end,
            )
            return []

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
        return [session]

    async def _sync_existing_session(self, session: Session) -> bool:
        schedule = session.schedule
        course = session.course
        if not schedule or not course or schedule.deleted_at is not None or course.deleted_at is not None:
            return False

        time_slot = schedule.time_slot
        if not time_slot:
            return False

        end_time_slot = schedule.end_time_slot or time_slot
        session_date = session.session_date or session.start_time.date()
        session_start = self._combine_date_time(session_date, time_slot.start_time)
        session_end = self._combine_date_time(session_date, end_time_slot.end_time)
        checkin_window_start, checkin_window_end = self._compute_checkin_window(
            course, session_start, session_end
        )

        old_end_time = session.end_time
        changed = self._apply_expected_session_fields(
            session,
            session_date=session_date,
            session_start=session_start,
            session_end=session_end,
            checkin_window_start=checkin_window_start,
            checkin_window_end=checkin_window_end,
        )

        mode = getattr(course, "attendance_mode", "preset") or "preset"
        now = datetime.now(timezone.utc)
        status_window_end = checkin_window_end if mode == "custom" else session_end
        was_closed_by_stale_end = (
            session.status == "closed"
            and mode in ("preset", "custom")
            and old_end_time is not None
            and old_end_time < status_window_end
            and now < status_window_end
        )
        if was_closed_by_stale_end:
            session.status = "scheduled"
            changed = True

        return changed

    @staticmethod
    def _apply_expected_session_fields(
        session: Session,
        *,
        session_date: date,
        session_start: datetime,
        session_end: datetime,
        checkin_window_start: datetime | None,
        checkin_window_end: datetime | None,
    ) -> bool:
        changed = False

        if session.session_date != session_date:
            session.session_date = session_date
            changed = True
        if session.start_time != session_start:
            session.start_time = session_start
            changed = True
        if session.end_time != session_end:
            session.end_time = session_end
            changed = True
        if session.checkin_window_start != checkin_window_start:
            session.checkin_window_start = checkin_window_start
            changed = True
        if session.checkin_window_end != checkin_window_end:
            session.checkin_window_end = checkin_window_end
            changed = True

        return changed

    def _combine_date_time(self, d: date, t: time) -> datetime:
        """Combine date + time into timezone-aware datetime (Vietnam UTC+7)."""
        naive = datetime.combine(d, t)
        # time_slot times are stored as naive (no tz) — they represent Vietnam local time
        return naive.replace(tzinfo=VIETNAM_TZ).astimezone(timezone.utc)

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
