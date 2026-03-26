from __future__ import annotations
"""Session repository — async DB queries for the `sessions` table."""
import uuid
from datetime import date
from typing import Sequence

from sqlalchemy import select, and_, func
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.session import Session
from app.repositories._base import BaseRepository


class SessionRepository(BaseRepository[Session]):
    """All database interactions for Session.

    All queries automatically exclude soft-deleted records.
    """

    model = Session

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, session_id: uuid.UUID) -> Session | None:
        result = await self.db.execute(
            select(Session)
            .options(joinedload(Session.course))
            .where(Session.id == session_id)
        )
        return result.scalar_one_or_none()

    async def get_by_course(
        self,
        course_id: uuid.UUID,
        session_date: date | None = None,
        status: str | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[Session]:
        conditions = [Session.course_id == course_id, Session.deleted_at.is_(None)]
        if session_date:
            from datetime import datetime
            start = datetime.combine(session_date, datetime.min.time())
            end = datetime.combine(session_date, datetime.max.time())
            conditions.append(Session.start_time >= start)
            conditions.append(Session.start_time <= end)
        if status:
            conditions.append(Session.status == status)
        result = await self.db.execute(
            select(Session)
            .where(and_(*conditions))
            .offset(skip)
            .limit(limit)
            .order_by(Session.start_time.desc())
        )
        return result.scalars().all()

    async def get_active_by_course(self, course_id: uuid.UUID) -> Sequence[Session]:
        result = await self.db.execute(
            select(Session).where(
                and_(
                    Session.course_id == course_id,
                    Session.status == "active",
                    Session.deleted_at.is_(None),
                )
            )
        )
        return result.scalars().all()

    async def list(
        self,
        course_id: uuid.UUID | None = None,
        session_date: date | None = None,
        status: str | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> tuple[Sequence[Session], int]:
        conditions = [Session.deleted_at.is_(None)]
        if course_id:
            conditions.append(Session.course_id == course_id)
        if session_date:
            from datetime import datetime
            start = datetime.combine(session_date, datetime.min.time())
            end = datetime.combine(session_date, datetime.max.time())
            conditions.append(Session.start_time >= start)
            conditions.append(Session.start_time <= end)
        if status:
            conditions.append(Session.status == status)
        where_clause = and_(*conditions)
        count_result = await self.db.execute(
            select(func.count()).select_from(Session).where(where_clause)
        )
        total = count_result.scalar_one()
        result = await self.db.execute(
            select(Session)
            .options(joinedload(Session.course))
            .where(where_clause)
            .offset(skip)
            .limit(limit)
            .order_by(Session.start_time.desc())
        )
        return result.unique().scalars().all(), total

    async def update_status(
        self,
        session_id: uuid.UUID,
        status: str,
        end_time=None,
        checkin_window_start=None,
        checkin_window_end=None,
    ) -> Session | None:
        result = await self.db.execute(
            select(Session)
            .options(joinedload(Session.course))
            .where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()
        if not session:
            return None
        session.status = status
        if end_time is not None:
            session.end_time = end_time
        if checkin_window_start is not None:
            session.checkin_window_start = checkin_window_start
        if checkin_window_end is not None:
            session.checkin_window_end = checkin_window_end
        await self.db.flush()
        await self.db.refresh(session)
        return session

    async def create(
        self,
        *,
        course_id: uuid.UUID,
        schedule_id: uuid.UUID | None = None,
        start_time,
        end_time=None,
        checkin_window_start=None,
        checkin_window_end=None,
        status: str = "scheduled",
    ) -> Session:
        session = Session(
            course_id=course_id,
            schedule_id=schedule_id,
            start_time=start_time,
            end_time=end_time,
            checkin_window_start=checkin_window_start,
            checkin_window_end=checkin_window_end,
            status=status,
        )
        self.db.add(session)
        await self.db.flush()
        await self.db.refresh(session)
        return session

    async def soft_delete(self, session: Session) -> None:
        await super().soft_delete(session)

    # ── Auto-update (Phase 6) ─────────────────────────────────────────────────────
    async def get_sessions_needing_activation(self) -> Sequence[Session]:
        """Return 'scheduled' sessions whose start_time has passed."""
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        result = await self.db.execute(
            select(Session).where(
                and_(
                    Session.status == "scheduled",
                    Session.start_time <= now,
                    Session.deleted_at.is_(None),
                )
            )
        )
        return result.scalars().all()

    async def get_sessions_needing_close(self) -> Sequence[Session]:
        """Return 'active' sessions whose end_time has passed."""
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        result = await self.db.execute(
            select(Session).where(
                and_(
                    Session.status == "active",
                    Session.end_time <= now,
                    Session.deleted_at.is_(None),
                )
            )
        )
        return result.scalars().all()

    async def auto_update_status(self) -> tuple[int, int]:
        """Auto-transition session statuses. Returns (activated_count, closed_count)."""
        activated = 0
        closed = 0

        for session in await self.get_sessions_needing_activation():
            session.status = "active"
            activated += 1

        for session in await self.get_sessions_needing_close():
            session.status = "closed"
            closed += 1

        if activated or closed:
            await self.db.flush()

        return activated, closed

    # ── Metrics (Phase 9) ────────────────────────────────────────────────────
    async def count_active(self) -> int:
        """Return count of currently active sessions."""
        result = await self.db.execute(
            select(func.count()).select_from(Session).where(
                and_(
                    Session.status == "active",
                    Session.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one()

    # ── Room-based queries (Phase 9) ──────────────────────────────────────
    async def get_by_room(
        self,
        room_id: uuid.UUID,
        session_date: date | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[Session]:
        """Get sessions for courses in a specific room.

        Phase 9: room-based session lookup.
        Finds courses assigned to the room, then returns their sessions.
        Sorted: currently active first, then upcoming by start_time.
        """
        from app.models.course import Course as CourseModel
        # Subquery: find courses in the given room
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

        conditions = [
            Session.course_id.in_(select(course_subq)),
            Session.deleted_at.is_(None),
        ]
        if session_date:
            from datetime import datetime
            start = datetime.combine(session_date, datetime.min.time())
            end = datetime.combine(session_date, datetime.max.time())
            conditions.append(Session.start_time >= start)
            conditions.append(Session.start_time <= end)

        result = await self.db.execute(
            select(Session)
            .options(joinedload(Session.course))
            .where(and_(*conditions))
            .offset(skip)
            .limit(limit)
            .order_by(Session.start_time.asc())
        )
        return result.unique().scalars().all()

    async def get_by_room_sorted(
        self,
        room_id: uuid.UUID,
        session_date: date | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> tuple[Sequence[Session], int]:
        """Get sessions for a room with active-first sorting + total count."""
        from app.models.course import Course as CourseModel
        from datetime import datetime
        from sqlalchemy import case

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

        conditions = [
            Session.course_id.in_(select(course_subq)),
            Session.deleted_at.is_(None),
        ]
        if session_date:
            start = datetime.combine(session_date, datetime.min.time())
            end = datetime.combine(session_date, datetime.max.time())
            conditions.append(Session.start_time >= start)
            conditions.append(Session.start_time <= end)

        where_clause = and_(*conditions)

        count_result = await self.db.execute(
            select(func.count()).select_from(Session).where(where_clause)
        )
        total = count_result.scalar_one()

        active_order = case(
            (Session.status == "active", 0),
            (Session.status == "scheduled", 1),
            else_=2,
        )
        result = await self.db.execute(
            select(Session)
            .options(
                joinedload(Session.course),
                joinedload(Session.attendance_config)
            )
            .where(where_clause)
            .order_by(active_order, Session.start_time.asc())
            .offset(skip)
            .limit(limit)
        )
        return result.unique().scalars().all(), total

    async def get_upcoming_sessions_by_teacher(
        self,
        teacher_id: int,
        limit: int = 10,
    ) -> Sequence[Session]:
        """Return currently active or upcoming sessions for a specific teacher.
        Sorted: active first, then closest upcoming.
        """
        from app.models.course import Course as CourseModel
        from sqlalchemy import case
        from datetime import datetime, timezone

        now = datetime.now(timezone.utc)

        # Find courses for this teacher
        course_subq = (
            select(CourseModel.id)
            .where(
                and_(
                    CourseModel.teacher_id == teacher_id,
                    CourseModel.deleted_at.is_(None),
                )
            )
            .subquery()
        )

        conditions = [
            Session.course_id.in_(select(course_subq)),
            Session.deleted_at.is_(None),
            # Filter sessions that haven't ended yet
            Session.end_time > now,
            Session.status != "closed",
        ]

        active_order = case(
            (Session.status == "active", 0),
            (Session.status == "scheduled", 1),
            else_=2,
        )

        result = await self.db.execute(
            select(Session)
            .options(joinedload(Session.course))
            .where(and_(*conditions))
            .order_by(active_order, Session.start_time.asc())
            .limit(limit)
        )
        return result.unique().scalars().all()

    async def get_sessions_by_teacher(
        self,
        teacher_id: int,
        session_date: date | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> tuple[Sequence[Session], int]:
        """Return all sessions for a specific teacher's courses."""
        from app.models.course import Course as CourseModel

        # Base query for courses owned by teacher
        course_stmt = select(CourseModel.id).where(
            and_(
                CourseModel.teacher_id == teacher_id,
                CourseModel.deleted_at.is_(None),
            )
        )

        conditions = [
            Session.course_id.in_(course_stmt),
            Session.deleted_at.is_(None),
        ]
        if session_date:
            from datetime import datetime
            start = datetime.combine(session_date, datetime.min.time())
            end = datetime.combine(session_date, datetime.max.time())
            conditions.append(Session.start_time >= start)
            conditions.append(Session.start_time <= end)

        where_clause = and_(*conditions)

        # Count
        count_result = await self.db.execute(
            select(func.count()).select_from(Session).where(where_clause)
        )
        total = count_result.scalar_one()

        # Data
        result = await self.db.execute(
            select(Session)
            .options(
                joinedload(Session.course).joinedload(CourseModel.room),
                joinedload(Session.schedule)
            )
            .where(where_clause)
            .order_by(Session.start_time.desc())
            .offset(skip)
            .limit(limit)
        )
        return result.unique().scalars().all(), total
