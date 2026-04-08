"""
Diagnostic script — runs synchronously to surface traceback for:
  - GET /api/v1/courses/
  - GET /api/v1/attendance/history
"""
import asyncio, traceback, sys, os
sys.path.insert(0, os.path.dirname(__file__))

USER_ID = "19c0116c-3b56-484e-a567-e0289afcf8a0"

async def main():
    from app.core.database import AsyncSessionLocal

    # ── Test 1: Courses ──────────────────────────────────────────
    print("=" * 60)
    print("TEST 1: CourseService.list_courses()")
    print("=" * 60)
    try:
        from app.services.course_service import CourseService
        async with AsyncSessionLocal() as db:
            svc = CourseService(db)
            result = await svc.list_courses(skip=0, limit=10)
            print("OK:", result)
    except Exception:
        traceback.print_exc()

    # ── Test 2: Attendance History ───────────────────────────────
    print()
    print("=" * 60)
    print("TEST 2: AttendanceService.get_role_based_history() as admin")
    print("=" * 60)
    try:
        from app.services.attendance_service import AttendanceService
        async with AsyncSessionLocal() as db:
            svc = AttendanceService(db)
            result = await svc.get_role_based_history(
                role="admin",
                user_id=USER_ID,
                course_id=None,
                skip=0,
                limit=5,
            )
            print("OK:", result)
    except Exception:
        traceback.print_exc()

    # ── Test 3: Attendance History as teacher ────────────────────
    print()
    print("=" * 60)
    print("TEST 3: AttendanceService.get_role_based_history() as teacher")
    print("=" * 60)
    try:
        from app.services.attendance_service import AttendanceService
        async with AsyncSessionLocal() as db:
            svc = AttendanceService(db)
            result = await svc.get_role_based_history(
                role="teacher",
                user_id=USER_ID,
                course_id=None,
                skip=0,
                limit=5,
            )
            print("OK:", result)
    except Exception:
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
