# Backend Error Handling & Common Issues

This document tracks known backend issues, root causes, and fixes applied.

---

## Issue: `_resolve_teacher_id` always requires teacher profile

**Severity:** High (blocks mutation endpoints for admin users)

**Affected Endpoints:**
- `POST /api/v1/courses/{course_id}/students/batch`
- `POST /api/v1/courses/{course_id}/students/{student_id}`
- `PUT /api/v1/courses/{course_id}/assign-room` (missing ownership check only)

**Root Cause:**

`_resolve_teacher_id()` defaults to `required=True`. When `teacher_id` is not provided, it tries to resolve the teacher profile from `user_id`. If the user is an admin (no teacher profile), it raises:

```
HTTPException(404): "Your user account is not linked to a teacher profile."
```

This causes a **404 response** instead of allowing admin access.

Additionally, `batch_enroll_students`, `enroll_student`, and `assign_room_to_course` were missing the ownership validation (`course.teacher_id == resolved_teacher_id`) that other mutation endpoints already had.

**Fix Applied:**

All three endpoints were updated to:
1. Pass `required=False` to `_resolve_teacher_id()` — allows admins to bypass teacher profile check
2. Validate ownership: admins (`resolved_teacher_id is None`) can act on any course; teachers can only act on courses they own
3. Return `403 Forbidden` ("You do not own this course.") for unauthorized teacher access

```python
# Pattern used in all fixed endpoints (courses.py):
resolved_teacher_id = await svc._resolve_teacher_id(
    teacher_id=None, user_id=user_id, required=False
)

# Admin (resolved_teacher_id is None) can act on any course
# Teacher can only act on their own courses
if resolved_teacher_id is not None and course.teacher_id != resolved_teacher_id:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="You do not own this course.",
    )
```

**Consistent Pattern (for future endpoints):**

All course mutation endpoints should follow this pattern:

| Scenario | `required` | Ownership Check |
|---|---|---|
| Admin (no teacher profile) | `False` | Skipped — can act on any course |
| Teacher | `False` | Must own `course.teacher_id` |
| `create_course` only | `True` | N/A — teacher profile always required |

**Date Fixed:** 2026-03-23
**File Fixed:** `backend/app/routers/v1/courses.py`
**Commit:** N/A (working copy)

---

## Issue: `CourseStudentDetail` schema missing `student_code` and `name`

**Severity:** Medium (enrolled students list shows empty name and "ID" instead of MSSV)

**Affected Endpoint:** `GET /api/v1/courses/{course_id}/students`

**Root Cause:**

The `CourseStudentDetail` Pydantic schema was missing `student_code` and `name` fields. The repository query (`get_students_with_face_status`) also didn't select them — only `student_id`, `user_id`, `pin`, `enrolled_at`, `has_face`, `embedding_count`. This meant the enrolled student list in Flutter showed:
- Name: "Học sinh #ID" (fallback, never the real name)
- Subtitle: "ID: X" (numeric database ID, not the MSSV)

**Fix Applied (4 files):**

### 1. Schema — `backend/app/schemas/v1/course.py`
Added `student_code` and `name` fields to `CourseStudentDetail`:
```python
class CourseStudentDetail(BaseModel):
    student_id: int
    student_code: Optional[str] = None
    name: Optional[str] = None
    user_id: Optional[str] = None
    ...
```

### 2. Repository — `backend/app/repositories/course_enrollment_repository.py`
Updated `get_students_with_face_status` to join with `User` table and select `student_code` and `full_name`:
```python
result = await self.db.execute(
    sa_select(
        CourseEnrollment.student_id,
        Student.student_code,
        User.full_name.label("name"),
        Student.user_id,
        ...
    )
    .join(Student, CourseEnrollment.student_id == Student.id)
    .join(User, Student.user_id == User.id, isouter=True)
    ...
)
```

### 3. Router — `backend/app/routers/v1/courses.py`
Updated the `list_course_students` handler to pass `student_code` and `name` to the schema:
```python
CourseStudentDetail(
    student_id=row.student_id,
    student_code=row.student_code,
    name=row.name,
    ...
)
```

### 4. Flutter Entity — `lib/entities/course_student.dart`
Added `studentCode` and `name` fields:
```dart
final String? studentCode;
final String? name;
```

### 5. Flutter UI — `lib/pages/course/course_detail_page.dart`
Updated `_buildStudentItem` to display `studentCode` (MSSV) instead of numeric `studentId`:
```dart
subtitle: Row(
  children: [
    if (student.studentCode != null) ...[
      Text('MSSV: ${student.studentCode}', ...),
    ],
    if (student.pin != null)
      Text('PIN: ${student.pin}', ...),
  ],
),
```

**Note:** The available students dialog (select students to enroll) already correctly displayed `student_code` and `full_name` — only the enrolled students list needed fixing.

**Date Fixed:** 2026-03-23
**Files Fixed:** `backend/app/schemas/v1/course.py`, `backend/app/repositories/course_enrollment_repository.py`, `backend/app/routers/v1/courses.py`, `lib/entities/course_student.dart`, `lib/pages/course/course_detail_page.dart`

---

## Issue: `enrolled_count` always returns 0 in course list

**Severity:** Low (cosmetic — count display always shows 0)

**Affected Endpoint:** `GET /api/v1/courses/`

**Root Cause:**

`CourseOut` schema has `enrolled_count: int = 0` as a default, but it was never populated. The repository and service had no logic to count enrolled students per course.

**Fix Applied (2 files):**

### 1. Repository — `backend/app/repositories/course_repository.py`
Added `count_enrolled(course_id)` method:
```python
async def count_enrolled(self, course_id: uuid.UUID) -> int:
    from app.models.course_enrollment import CourseEnrollment
    result = await self.db.execute(
        select(sa_func.count()).select_from(CourseEnrollment).where(
            CourseEnrollment.course_id == course_id
        )
    )
    return result.scalar_one()
```

### 2. Service — `backend/app/services/course_service.py`
Updated `_build_course_out` to query the count:
```python
async def _build_course_out(self, course: "Course") -> CourseOut:
    out = CourseOut.model_validate(course)
    out.enrolled_count = await self.repo.count_enrolled(course.id)
    ...
```

**Date Fixed:** 2026-03-23
**Files Fixed:** `backend/app/repositories/course_repository.py`, `backend/app/services/course_service.py`
