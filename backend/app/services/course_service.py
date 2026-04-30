from __future__ import annotations
"""Course service — CRUD for the /courses endpoints."""
import uuid
from typing import TYPE_CHECKING

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.course import Course
from app.models.schedule import Schedule
from app.models.time_slot import TimeSlot
from app.repositories.course_repository import CourseRepository
from app.repositories.teacher_repository import TeacherRepository
from app.schemas.v1.course import CourseCreate, CourseUpdate, CourseOut, CourseList

if TYPE_CHECKING:
    from app.models.course import Course
    from app.models.schedule import Schedule


class CourseService:
    """Business logic for course management."""

    def __init__(self, db: AsyncSession) -> None:
        self.repo = CourseRepository(db)
        self._teacher_repo: TeacherRepository | None = None
        self._db = db

    @property
    def teacher_repo(self) -> TeacherRepository:
        if self._teacher_repo is None:
            self._teacher_repo = TeacherRepository(self._db)
        return self._teacher_repo

    # ── Static helpers (used by thin routers) ────────────────────────────────

    @staticmethod
    async def resolve_teacher_id_from_user(
        db: AsyncSession,
        teacher_id: int | None,
        user_id: str,
        required: bool = True,
    ) -> int | None:
        """Resolve teacher_id: use provided value, or resolve from user_id.

        Thin-layer routers call this; all mapping logic lives in the service.
        """
        teacher_repo = TeacherRepository(db)
        if teacher_id is not None:
            teacher = await teacher_repo.get_by_id(teacher_id)
            if not teacher or teacher.deleted_at is not None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Teacher not found.",
                )
            return teacher_id

        teacher = await teacher_repo.get_by_user_id(uuid.UUID(user_id))
        if not teacher or teacher.deleted_at is not None:
            if not required:
                return None
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Your user account is not linked to a teacher profile.",
            )
        return teacher.id

    # ── Internal helpers ─────────────────────────────────────────────────────

    async def _resolve_teacher_id(
        self,
        teacher_id: int | None,
        user_id: str,
        required: bool = True,
    ) -> int | None:
        """Instance wrapper for resolve_teacher_id_from_user."""
        return await self.resolve_teacher_id_from_user(
            self._db, teacher_id, user_id, required=required
        )

    async def _resolve_student_id(self, user_id: str) -> int | None:
        """Resolve student_id from user_id."""
        from app.repositories.student_repository import StudentRepository
        from sqlalchemy import select
        from app.models.student import Student
        import uuid

        result = await self._db.execute(
            select(Student).where(
                Student.user_id == uuid.UUID(user_id),
                Student.deleted_at.is_(None)
            )
        )
        student = result.scalar_one_or_none()
        return student.id if student else None

    async def _get_slot_ids_in_range(
        self,
        start_slot_id: int,
        end_slot_id: int,
    ) -> list[int]:
        """Return all time_slot ids with period_number between start and end (inclusive)."""
        result = await self._db.execute(
            select(TimeSlot)
            .where(
                TimeSlot.period_number >= (
                    select(TimeSlot.period_number).where(TimeSlot.id == start_slot_id).scalar_subquery()
                ),
                TimeSlot.period_number <= (
                    select(TimeSlot.period_number).where(TimeSlot.id == end_slot_id).scalar_subquery()
                ),
            )
            .order_by(TimeSlot.period_number)
        )
        slots = result.scalars().all()
        return [s.id for s in slots]

    async def _validate_schedule_conflict(
        self,
        *,
        day_of_week: int,
        time_slot_id: int,
        teacher_id: int | None,
        room_id: uuid.UUID | None,
        exclude_course_id: uuid.UUID | None = None,
    ) -> None:
        """Prevent duplicate teaching slots for the same teacher or room."""

        day_label_map = {
            1: "Thứ Hai",
            2: "Thứ Ba",
            3: "Thứ Tư",
            4: "Thứ Năm",
            5: "Thứ Sáu",
            6: "Thứ Bảy",
            7: "Chủ Nhật",
        }
        day_label = day_label_map.get(day_of_week, f"Thứ {day_of_week}")

        if teacher_id is not None:
            teacher_stmt = (
                select(Course, Schedule, TimeSlot)
                .join(Schedule, Schedule.course_id == Course.id)
                .join(TimeSlot, TimeSlot.id == Schedule.time_slot_id)
                .where(
                    Course.deleted_at.is_(None),
                    Schedule.deleted_at.is_(None),
                    Course.teacher_id == teacher_id,
                    Schedule.day_of_week == day_of_week,
                    Schedule.time_slot_id == time_slot_id,
                )
            )
            if exclude_course_id is not None:
                teacher_stmt = teacher_stmt.where(Course.id != exclude_course_id)

            teacher_conflict = (await self._db.execute(teacher_stmt)).first()
            if teacher_conflict is not None:
                conflict_course, _, conflict_slot = teacher_conflict
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=(
                        f"Giảng viên đã có học phần '{conflict_course.course_name}' "
                        f"vào {day_label}, tiết {conflict_slot.period_number}."
                    ),
                )

        if room_id is not None:
            room_stmt = (
                select(Course, Schedule, TimeSlot)
                .join(Schedule, Schedule.course_id == Course.id)
                .join(TimeSlot, TimeSlot.id == Schedule.time_slot_id)
                .where(
                    Course.deleted_at.is_(None),
                    Schedule.deleted_at.is_(None),
                    Course.room_id == room_id,
                    Schedule.day_of_week == day_of_week,
                    Schedule.time_slot_id == time_slot_id,
                )
            )
            if exclude_course_id is not None:
                room_stmt = room_stmt.where(Course.id != exclude_course_id)

            room_conflict = (await self._db.execute(room_stmt)).first()
            if room_conflict is not None:
                conflict_course, _, conflict_slot = room_conflict
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=(
                        f"Phòng học đã được dùng bởi học phần '{conflict_course.course_name}' "
                        f"vào {day_label}, tiết {conflict_slot.period_number}."
                    ),
                )

    # ── CRUD ────────────────────────────────────────────────────

    async def create_course(
        self,
        req: CourseCreate,
        teacher_id: int | None,
        user_id: str,
    ) -> CourseOut:
        """Create a new course.

        - If teacher_id is provided, use it directly (admin case).
        - Otherwise, resolve from user_id (regular teacher).
        """
        resolved_teacher_id = await self._resolve_teacher_id(teacher_id, user_id)

        if req.department_id:
            from app.repositories.department_repository import DepartmentRepository
            dept_repo = DepartmentRepository(self._db)
            dept = await dept_repo.get_by_id(req.department_id)
            if not dept:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Department not found.",
                )

        if req.room_id:
            from app.repositories.room_repository import RoomRepository
            room_repo = RoomRepository(self._db)
            room = await room_repo.get_by_id(req.room_id)
            if not room or room.is_deleted:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Room not found.",
                )

        # Resolve effective slot range (new API takes priority over legacy time_slot_id)
        eff_start_slot = req.start_time_slot_id or req.time_slot_id
        eff_end_slot = req.end_time_slot_id or eff_start_slot

        has_schedule = req.day_of_week is not None and eff_start_slot is not None
        if (req.day_of_week is None) != (eff_start_slot is None):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cần cung cấp đầy đủ cả thứ học và tiết học.",
            )

        if eff_end_slot is not None and eff_start_slot is not None and eff_end_slot < eff_start_slot:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tiết kết thúc phải >= tiết bắt đầu.",
            )

        if has_schedule:
            # Conflict check: validate only the start slot (covers the whole block)
            await self._validate_schedule_conflict(
                day_of_week=req.day_of_week,
                time_slot_id=eff_start_slot,
                teacher_id=resolved_teacher_id,
                room_id=req.room_id,
            )

        course = await self.repo.create(
            course_name=req.course_name,
            teacher_id=resolved_teacher_id,
            course_code=req.course_code,
            department_id=req.department_id,
            room_id=req.room_id,
            attendance_mode=req.attendance_mode,
            custom_window_start_minutes=req.custom_window_start_minutes,
            custom_window_end_minutes=req.custom_window_end_minutes,
            total_sessions=req.total_sessions,
            credits=req.credits,
        )

        # ── Automatic Schedule creation (1 record, stores start→end range) ──
        if has_schedule:
            from app.models.schedule import Schedule
            self._db.add(
                Schedule(
                    course_id=course.id,
                    day_of_week=req.day_of_week,
                    time_slot_id=eff_start_slot,
                    end_time_slot_id=eff_end_slot if eff_end_slot != eff_start_slot else None,
                )
            )
            await self._db.flush()
            latest = await self.repo.get_by_id(course.id)
            if latest:
                course = latest

        return await self._build_course_out(course)

    async def get_course(self, course_id: uuid.UUID) -> CourseOut:
        course = await self.repo.get_by_id(course_id)
        if not course:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Course '{course_id}' not found.",
            )
        return await self._build_course_out(course)

    async def list_courses(
        self,
        skip: int = 0,
        limit: int = 200,
        department_id: uuid.UUID | None = None,
    ) -> CourseList:
        if department_id:
            courses = await self.repo.get_by_department(department_id)
            return CourseList(
                total=len(courses),
                items=[await self._build_course_out(c) for c in courses]
            )
        courses = await self.repo.get_all(skip=skip, limit=limit)
        total = await self.repo.count()
        return CourseList(
            total=total,
            items=[await self._build_course_out(c) for c in courses],
        )

    async def list_my_courses(
        self,
        teacher_id: int | None,
        user_id: str,
    ) -> CourseList:
        """List courses relevant to the current user (Teacher, Creator, or Student)."""
        all_courses = []
        seen_ids = set()

        def add_unique(courses):
            for c in courses:
                if c.id not in seen_ids:
                    all_courses.append(c)
                    seen_ids.add(c.id)

        # 1. As Teacher (resolved from teacher_id or user_id)
        resolved_teacher_id = await self._resolve_teacher_id(
            teacher_id, user_id, required=False
        )
        if resolved_teacher_id is not None:
            teacher_courses = await self.repo.get_by_teacher(resolved_teacher_id)
            add_unique(teacher_courses)

        # 2. As Creator (independent of teacher profile)
        import uuid
        creator_courses = await self.repo.get_by_creator(uuid.UUID(user_id))
        add_unique(creator_courses)

        # 3. As Student (enrolled in course)
        resolved_student_id = await self._resolve_student_id(user_id)
        if resolved_student_id is not None:
            student_courses = await self.repo.get_by_student(resolved_student_id)
            add_unique(student_courses)

        return CourseList(
            total=len(all_courses),
            items=[await self._build_course_out(c) for c in all_courses],
        )

    async def update_course(
        self,
        course_id: uuid.UUID,
        req: CourseUpdate,
        teacher_id: int | None,
        user_id: str,
        role: str,
    ) -> CourseOut:
        """Update a course. Admin (no teacher profile) can update any course."""
        import uuid

        # 1. Authorize based ONLY on the user making the request
        # (do not use the target req.teacher_id for authorization logic!)
        current_teacher = await self.teacher_repo.get_by_user_id(uuid.UUID(user_id))
        current_teacher_id = current_teacher.id if current_teacher and current_teacher.deleted_at is None else None

        course = await self.repo.get_by_id(course_id)
        if not course:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Course '{course_id}' not found.",
            )

        # Admin (role == "admin") can update any course
        # Teacher (role == "teacher") can only update their own courses
        if role == "teacher":
            if current_teacher_id is not None and course.teacher_id != current_teacher_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="You do not own this course.",
                )
            # Restriction: Only allow attendance config fields for teachers
            # Clear all other fields from the req object internally
            allowed_fields = {"attendance_mode", "custom_window_start_minutes", "custom_window_end_minutes"}
            original_req_dict = req.model_dump(exclude_unset=True)
            for key in original_req_dict:
                if key not in allowed_fields:
                    setattr(req, key, None)
        elif role != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to update courses.",
            )

        if req.department_id is not None:
            from app.repositories.department_repository import DepartmentRepository
            dept_repo = DepartmentRepository(self._db)
            dept = await dept_repo.get_by_id(req.department_id)
            if not dept:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Department not found.",
                )

        if req.room_id is not None:
            from app.repositories.room_repository import RoomRepository
            room_repo = RoomRepository(self._db)
            room = await room_repo.get_by_id(req.room_id)
            if not room or room.is_deleted:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Room not found.",
                )

        # Determine target teacher_id: provided value, existing value (for admin), or resolved (for teacher)
        target_teacher_id = course.teacher_id  # Default: keep existing
        if req.teacher_id is not None:
            # Validate reassignment
            new_teacher = await self.teacher_repo.get_by_id(req.teacher_id)
            if not new_teacher or new_teacher.deleted_at is not None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Teacher not found.",
                )
            target_teacher_id = req.teacher_id
        elif current_teacher_id is not None:
            # Teacher case: use current teacher_id
            target_teacher_id = current_teacher_id

        target_room_id = req.room_id if req.room_id is not None else course.room_id

        existing_schedule = next(
            (s for s in getattr(course, "schedules", []) if s.deleted_at is None),
            None,
        )
        effective_day = (
            req.day_of_week
            if req.day_of_week is not None
            else (existing_schedule.day_of_week if existing_schedule else None)
        )
        effective_start_slot = req.start_time_slot_id or req.time_slot_id
        effective_slot = (
            effective_start_slot
            if effective_start_slot is not None
            else (existing_schedule.time_slot_id if existing_schedule else None)
        )
        effective_end_slot = (
            req.end_time_slot_id
            if req.end_time_slot_id is not None
            else (
                (existing_schedule.end_time_slot_id or existing_schedule.time_slot_id)
                if existing_schedule
                else effective_slot
            )
        )

        if (
            (req.day_of_week is None) != (effective_start_slot is None)
            and existing_schedule is None
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cần cung cấp đầy đủ cả thứ học và tiết học.",
            )

        if (
            effective_slot is not None
            and effective_end_slot is not None
            and effective_end_slot < effective_slot
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tiáº¿t káº¿t thÃºc khÃ´ng Ä‘Æ°á»£c nhá» hÆ¡n tiáº¿t báº¯t Ä‘áº§u.",
            )

        if effective_day is not None and effective_slot is not None:
            await self._validate_schedule_conflict(
                day_of_week=effective_day,
                time_slot_id=effective_slot,
                teacher_id=target_teacher_id,
                room_id=target_room_id,
                exclude_course_id=course.id,
            )

        updated = await self.repo.update(
            course,
            course_name=req.course_name,
            course_code=req.course_code,
            teacher_id=target_teacher_id,
            department_id=req.department_id,
            room_id=req.room_id,
            attendance_mode=req.attendance_mode,
            custom_window_start_minutes=req.custom_window_start_minutes,
            custom_window_end_minutes=req.custom_window_end_minutes,
            total_sessions=req.total_sessions,
            credits=req.credits,
        )

        # ── Update checkin windows for existing sessions if attendance config changed ──
        if req.attendance_mode is not None or req.custom_window_start_minutes is not None or req.custom_window_end_minutes is not None:
            from app.models.session import Session
            from sqlalchemy import select
            from datetime import timedelta

            sessions_to_update = await self._db.execute(
                select(Session).where(
                    Session.course_id == course.id,
                    Session.status.in_(["scheduled", "active", "paused"]),
                    Session.deleted_at.is_(None)
                )
            )
            for session in sessions_to_update.scalars():
                mode = getattr(course, "attendance_mode", "preset") or "preset"
                start_min = getattr(course, "custom_window_start_minutes", 0) or 0
                end_min = getattr(course, "custom_window_end_minutes", 30) or 30

                if mode == "custom" and session.start_time and session.end_time:
                    window_start = session.start_time + timedelta(minutes=start_min)
                    window_end = session.start_time + timedelta(minutes=end_min)
                    if window_end > session.end_time:
                        window_end = session.end_time
                    session.checkin_window_start = window_start
                    session.checkin_window_end = window_end
                elif mode == "preset" and session.start_time and session.end_time:
                    session.checkin_window_start = session.start_time
                    session.checkin_window_end = session.end_time
                else:
                    session.checkin_window_start = None
                    session.checkin_window_end = None

            await self._db.flush()

        # ── Automatic Schedule update (multi-slot support) ─────────────────
        normalized_end_slot = (
            effective_end_slot
            if effective_end_slot is not None and effective_end_slot != effective_slot
            else None
        )
        schedule_changed = (
            req.day_of_week is not None
            or effective_start_slot is not None
            or req.end_time_slot_id is not None
        )

        if schedule_changed and effective_day is not None and effective_slot is not None:
            from app.models.schedule import Schedule

            stale_duplicates = [
                s
                for s in getattr(course, "schedules", [])
                if s.deleted_at is not None
                and s.day_of_week == effective_day
                and s.time_slot_id == effective_slot
            ]
            for stale_schedule in stale_duplicates:
                await self._db.delete(stale_schedule)

            if existing_schedule is not None:
                existing_schedule.day_of_week = effective_day
                existing_schedule.time_slot_id = effective_slot
                existing_schedule.end_time_slot_id = normalized_end_slot

            else:
                self._db.add(
                    Schedule(
                        course_id=course.id,
                        day_of_week=effective_day,
                        time_slot_id=effective_slot,
                        end_time_slot_id=normalized_end_slot,
                    )
                )
            await self._db.flush()

            latest = await self.repo.get_by_id(course.id)
            if latest:
                course = latest

        return await self._build_course_out(course)

    async def _fetch_slot(self, slot_id: int) -> "TimeSlot | None":
        from app.repositories.time_slot_repository import TimeSlotRepository
        try:
            return await TimeSlotRepository(self._db).get_by_id(slot_id)
        except Exception:
            return None

    async def _build_course_out(self, course: "Course") -> CourseOut:
        """Helper to build CourseOut with schedule info (single Schedule record)."""
        out = CourseOut.model_validate(course)
        out.enrolled_count = await self.repo.count_enrolled(course.id)

        schedules = getattr(course, "schedules", [])
        if schedules:
            active = [s for s in schedules if s.deleted_at is None]
            if active:
                sched = active[0]  # Always a single record now
                out.day_of_week = sched.day_of_week

                start_slot_id = sched.time_slot_id
                end_slot_id = sched.end_time_slot_id or sched.time_slot_id

                out.time_slot_id = start_slot_id
                out.start_time_slot_id = start_slot_id
                out.end_time_slot_id = end_slot_id

                # Resolve period numbers for display
                def _period(s_obj, slot_id: int) -> str | None:
                    # Try loaded relationship first
                    if slot_id == s_obj.time_slot_id and hasattr(s_obj, "time_slot") and s_obj.time_slot:
                        return str(s_obj.time_slot.period_number)
                    if slot_id == s_obj.end_time_slot_id and hasattr(s_obj, "end_time_slot") and s_obj.end_time_slot:
                        return str(s_obj.end_time_slot.period_number)
                    return None

                start_period = _period(sched, start_slot_id)
                end_period = _period(sched, end_slot_id)

                # DB fallback
                if start_period is None:
                    ts = await self._fetch_slot(start_slot_id)
                    start_period = str(ts.period_number) if ts else None
                if end_period is None:
                    ts = await self._fetch_slot(end_slot_id)
                    end_period = str(ts.period_number) if ts else None

                out.start_time_slot_name = f"Tiết {start_period}" if start_period else None
                out.end_time_slot_name = f"Tiết {end_period}" if end_period else None

                # Display: "Tiết 1" or "Tiết 1-3"
                if start_period and end_period and start_period != end_period:
                    out.time_slot_name = f"Tiết {start_period}-{end_period}"
                else:
                    out.time_slot_name = f"Tiết {start_period}" if start_period else None

        return out

    async def delete_course(
        self,
        course_id: uuid.UUID,
        teacher_id: int | None,
        user_id: str,
    ) -> None:
        """Delete a course. Admin (no teacher profile) can delete any course."""
        resolved_teacher_id = await self._resolve_teacher_id(
            teacher_id, user_id, required=False
        )

        course = await self.repo.get_by_id(course_id)
        if not course:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Course '{course_id}' not found.",
            )
        # Admin (resolved_teacher_id is None) can delete any course
        # Teacher can only delete their own courses
        if resolved_teacher_id is not None and course.teacher_id != resolved_teacher_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not own this course.",
            )
        await self.repo.soft_delete(course)
