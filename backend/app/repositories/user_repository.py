from __future__ import annotations
"""User repository — raw async DB queries for the `users` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.user import User


class UserRepository:
    """All database interactions for the User model.

    Never raises HTTP exceptions — that is the service layer's responsibility.
    Returns None when a record is not found.
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ── Read ──────────────────────────────────────────────────
    async def get_by_id(self, user_id: str | uuid.UUID) -> User | None:
        uid = uuid.UUID(str(user_id)) if not isinstance(user_id, uuid.UUID) else user_id
        from app.models.student import Student
        result = await self.db.execute(
            select(User)
            .options(
                selectinload(User.student_profile).selectinload(Student.student_group),
                selectinload(User.teacher_profile)
            )
            .where(
                and_(User.id == uid, User.deleted_at.is_(None))
            )
        )
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        from app.models.student import Student
        result = await self.db.execute(
            select(User)
            .options(
                selectinload(User.student_profile).selectinload(Student.student_group),
                selectinload(User.teacher_profile)
            )
            .where(
                and_(User.email == email.lower(), User.deleted_at.is_(None))
            )
        )
        return result.scalar_one_or_none()

    async def get_all(
        self,
        skip: int = 0,
        limit: int = 100,
        role: str | None = None,
    ) -> Sequence[User]:
        query = select(User).where(User.deleted_at.is_(None))
        if role:
            query = query.where(User.role == role)
        if role == "student":
            query = query.options(selectinload(User.student_profile))
        elif role == "teacher":
            query = query.options(selectinload(User.teacher_profile))
        else:
            query = query.options(
                selectinload(User.student_profile),
                selectinload(User.teacher_profile)
            )
        result = await self.db.execute(
            query
            .offset(skip)
            .limit(limit)
            .order_by(User.created_at.desc())
        )
        return result.scalars().all()

    async def count(self, role: str | None = None) -> int:
        from sqlalchemy import func as sa_func
        query = select(sa_func.count()).select_from(User).where(
            User.deleted_at.is_(None)
        )
        if role:
            query = query.where(User.role == role)
        result = await self.db.execute(query)
        return result.scalar_one()

    # ── Write ─────────────────────────────────────────────────
    async def create(
        self,
        *,
        email: str,
        password_hash: str,
        full_name: str,
        role: str = "student",
        pin: str | None = None,
        job_title: str | None = None,
    ) -> User:
        user = User(
            email=email.lower(),
            password_hash=password_hash,
            full_name=full_name,
            role=role,
        )
        self.db.add(user)
        # Bắt buộc flush để tạo ra user.id trước khi link với profile
        await self.db.flush()

        # Tạo profile tương ứng cho từng Role
        if role == "student":
            from app.models.student import Student
            student_profile = Student(
                user_id=user.id,
                student_code=pin,
            )
            
            # Map job_title (passed as class name) to StudentGroup
            if job_title:
                from sqlalchemy import select
                from app.models.student_group import StudentGroup
                group_query = select(StudentGroup).where(StudentGroup.code == job_title)
                group_result = await self.db.execute(group_query)
                group = group_result.scalar_one_or_none()
                
                if not group:
                    group = StudentGroup(code=job_title, name=job_title)
                    self.db.add(group)
                    await self.db.flush()
                
                student_profile.student_group_id = group.id
                student_profile.student_group = group
                
            self.db.add(student_profile)
            user.student_profile = student_profile
        elif role == "teacher":
            from app.models.teacher import Teacher
            teacher_profile = Teacher(
                user_id=user.id,
                teacher_id=pin,
            )
            self.db.add(teacher_profile)
            user.teacher_profile = teacher_profile

        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def update_password(self, user: User, new_hash: str) -> User:
        user.password_hash = new_hash
        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def update_avatar(self, user: User, avatar_url: str) -> User:
        """Update the avatar_url field on a user record."""
        user.avatar_url = avatar_url
        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def soft_delete(self, user: User) -> None:
        """Soft delete: sets deleted_at."""
        from datetime import datetime, timezone
        user.deleted_at = datetime.now(timezone.utc)
        await self.db.flush()
