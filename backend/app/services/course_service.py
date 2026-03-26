from __future__ import annotations
"""Course service — CRUD for the /courses endpoints."""
import uuid
from typing import TYPE_CHECKING

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

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

        course = await self.repo.create(
            course_name=req.course_name,
            teacher_id=resolved_teacher_id,
            course_code=req.course_code,
            department_id=req.department_id,
            room_id=req.room_id,
            attendance_mode=req.attendance_mode,
            attendance_before_minutes=req.attendance_before_minutes,
            attendance_after_minutes=req.attendance_after_minutes,
        )

        # ── Phase 10: Automatic Schedule creation ───────────────────────────
        if req.day_of_week is not None and req.time_slot_id is not None:
            from app.models.schedule import Schedule
            schedule = Schedule(
                course_id=course.id,
                day_of_week=req.day_of_week,
                time_slot_id=req.time_slot_id,
            )
            self._db.add(schedule)
            await self._db.flush()
            # RE-FETCH to get the new schedule and keep teacher/user info loaded
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
    ) -> CourseOut:
        """Update a course. Admin (no teacher profile) can update any course."""
        resolved_teacher_id = await self._resolve_teacher_id(
            teacher_id, user_id, required=False
        )

        course = await self.repo.get_by_id(course_id)
        if not course:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Course '{course_id}' not found.",
            )
        # Admin (resolved_teacher_id is None) can update any course
        # Teacher can only update their own courses
        if resolved_teacher_id is not None and course.teacher_id != resolved_teacher_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not own this course.",
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
        elif resolved_teacher_id is not None:
            # Teacher case: use resolved teacher_id
            target_teacher_id = resolved_teacher_id

        updated = await self.repo.update(
            course,
            course_name=req.course_name,
            course_code=req.course_code,
            teacher_id=target_teacher_id,
            department_id=req.department_id,
            room_id=req.room_id,
            attendance_mode=req.attendance_mode,
            attendance_before_minutes=req.attendance_before_minutes,
            attendance_after_minutes=req.attendance_after_minutes,
        )

        # ── Phase 10: Automatic Schedule update ───────────────────────────
        if req.day_of_week is not None or req.time_slot_id is not None:
            from app.repositories.schedule_repository import ScheduleRepository
            from app.models.schedule import Schedule
            schedule_repo = ScheduleRepository(self._db)
            schedules = await schedule_repo.get_by_course(course.id)

            if schedules:
                # Update the first one
                await schedule_repo.update(
                    schedules[0],
                    day_of_week=req.day_of_week,
                    time_slot_id=req.time_slot_id,
                )
            elif req.day_of_week is not None and req.time_slot_id is not None:
                # Create new one if it doesn't exist
                new_sched = Schedule(
                    course_id=course.id,
                    day_of_week=req.day_of_week,
                    time_slot_id=req.time_slot_id,
                )
                self._db.add(new_sched)
                await self._db.flush()

            # RE-FETCH to get the new schedule and keep teacher/user info loaded
            latest = await self.repo.get_by_id(course.id)
            if latest:
                course = latest

        return await self._build_course_out(course)

    async def _build_course_out(self, course: "Course") -> CourseOut:
        """Helper to build CourseOut with schedule info."""
        out = CourseOut.model_validate(course)
        out.enrolled_count = await self.repo.count_enrolled(course.id)

        # Safely check if 'schedules' relationship is loaded
        # In async SQLAlchemy, accessing an un-loaded relation raises an error.
        schedules = getattr(course, "schedules", [])

        # Filter for active ones (this might still trigger lazy load if 'schedules' is a lazy relation)
        # To be absolutely safe in async, we check the object state if possible,
        # but hasattr/getattr usually triggers it.
        # However, for new/refreshed objects it might be OK if they were joinedloaded.

        if schedules:
            active_schedules = [s for s in schedules if s.deleted_at is None]
            if active_schedules:
                primary: "Schedule" = active_schedules[0]
                out.day_of_week = primary.day_of_week
                out.time_slot_id = primary.time_slot_id

                # Fetch time slot info safely
                ts_name = None
                if hasattr(primary, "time_slot") and primary.time_slot:
                    ts_name = f"Tiết {primary.time_slot.period_number}"
                else:
                    # Fallback: fetch it from DB
                    try:
                        from app.repositories.time_slot_repository import TimeSlotRepository
                        ts_repo = TimeSlotRepository(self._db)
                        ts = await ts_repo.get_by_id(primary.time_slot_id)
                        if ts:
                            ts_name = f"Tiết {ts.period_number}"
                    except Exception:
                        pass
                out.time_slot_name = ts_name

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
