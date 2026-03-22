# Phase 8: Production Hardening — Implementation Report

**Date**: 2026-03-21
**Status**: Completed

---

## Overview

Phase 8 production hardening was implemented across 10 phases, touching 35+ files including 5 new migration files, 8 new service/core files, and numerous refactors to the existing codebase.

---

## Phase 1: Database Constraints & Indexes (Migrations 0019–0022)

### Files Changed

| File | Type | Change |
|------|------|--------|
| `alembic/versions/0019_add_production_constraints.py` | **New** | UNIQUE on `(schedule_id, session_date)`, CHECK on `status IN ('scheduled','active','closed')`, UNIQUE on `departments.code` |
| `alembic/versions/0020_add_performance_indexes.py` | **New** | Composite indexes on sessions, attendance; partial indexes on face_embeddings, devices, course_enrollments |
| `alembic/versions/0021_refactor_attendance_mode_enum.py` | **New** | Renames `attendance_mode` values: `fixed` → `preset` |
| `alembic/versions/0022_refactor_device_course_to_room.py` | **New** | Drops `devices.course_id` FK column (Phase 5 change) |
| `app/models/course.py` | Modified | `attendance_mode` default `fixed` → `preset` |
| `app/models/session.py` | Modified | `attendance_mode` fallback `fixed` → `preset` |
| `app/schemas/v1/course.py` | Modified | `Literal["fixed", ...]` → `Literal["preset", ...]` |
| `app/services/session_generator_service.py` | Modified | `attendance_mode` default `fixed` → `preset` |
| `app/repositories/course_repository.py` | Modified | Default `attendance_mode` `fixed` → `preset` |

### Notes
- The `attendance_mode` values `preset`, `flexible`, `custom` now map as: `preset` = window = start ± 30 min; `flexible` = no window restriction; `custom` = window = session.checkin_window_start/end
- The UNIQUE constraint `(schedule_id, session_date)` prevents duplicate session generation idempotently at the DB level

---

## Phase 2: Transaction Safety

### Files Changed

| File | Type | Change |
|------|------|--------|
| `app/core/transaction.py` | **New** | `@asynccontextmanager async def transaction(db)` — unified transaction boundary |
| `app/services/attendance_service.py` | Modified | Added `await db.commit()` after record creation; validates all in one transaction |
| `app/services/anti_cheat_service.py` | Modified | Changed `update_device_last_active` from `db.commit()` → `db.flush()` |
| `app/services/session_generator_service.py` | Modified | Wrapped batch session creation in `async with self.db.begin()` |
| `app/services/department_service.py` | Modified | Added `count_teachers` and `count_courses` guards before deletion |
| `app/repositories/department_repository.py` | Modified | Added `count_courses()` method |

### Notes
- The `@transaction` context manager provides auto-commit on success and auto-rollback on exception
- All `create_attendance` operations now explicitly `commit()` to ensure atomicity across the service and its callers
- Anti-cheat service no longer issues independent commits (all flushing is controlled by the caller)

---

## Phase 3: Idempotent APIs

### Files Changed

| File | Type | Change |
|------|------|--------|
| `app/services/attendance_service.py` | Modified | Duplicate check-in now returns existing record instead of raising HTTP 409 |

### Behavior Change
- **Before**: 2nd check-in attempt → `409 Conflict`
- **After**: 2nd check-in attempt → returns the existing attendance record (HTTP 200)

This makes the check-in endpoint idempotent and safe for retries from devices or network re-transmissions.

---

## Phase 4: Centralized AttendanceValidator

### Files Changed

| File | Type | Change |
|------|------|--------|
| `app/services/attendance_validator.py` | **New** | `AttendanceValidator` class with individual + batch validation methods |
| `app/services/attendance_service.py` | Modified | Instantiates `AttendanceValidator`; AntiCheatService calls still used for individual checks |
| `app/services/__init__.py` | Modified | Exported `AttendanceValidator` |

### Validator Methods
| Method | Purpose |
|--------|---------|
| `validate_session()` | Session exists + not deleted |
| `validate_session_active()` | Session status is 'active' |
| `validate_student()` | Student exists |
| `validate_enrolled()` | Student enrolled in session's course |
| `validate_device()` | Device active + room matches schedule room |
| `validate_checkin_window()` | Respects attendance_mode, enforces time window |
| `validate_all()` | Runs all validations in sequence, returns first failure |
| `get_existing_attendance()` | Returns existing record for idempotent deduplication |

---

## Phase 5: Device-Room Decoupling

### Files Changed

| File | Type | Change |
|------|------|--------|
| `app/models/device.py` | Modified | Removed `course_id` FK column and `course` relationship; kept `room` |
| `app/models/course.py` | Modified | Removed `devices` relationship |
| `app/schemas/v1/device.py` | Modified | Removed `course_id` field; `room` made optional |
| `app/routers/v1/devices.py` | Modified | Device create/update no longer accept `course_id` |
| `app/repositories/device_repository.py` | Modified | Replaced `get_by_course()` with `get_by_room()` |
| `app/services/anti_cheat_service.py` | Modified | Device-course check → device-room matching |
| `app/services/attendance_validator.py` | Modified | Device-room matching via `device.room == schedule.room` |
| `app/services/device_service.py` | Modified | `sync_data()` now finds students/sessions by room match instead of course_id |
| `app/services/face_service.py` | Modified | Added `export_for_student_ids()` method |
| `app/repositories/face_repository.py` | Modified | Added `get_by_student_ids()` method |
| `alembic/versions/0022_refactor_device_course_to_room.py` | **New** | Migration to drop `course_id` column |

### Device-Room Matching Logic
```
device.room == schedule.room  (both must be set)
OR
device.room is NULL  (unrestricted)
OR
schedule.room is NULL  (unrestricted)
```

---

## Phase 6: Performance Optimization

### Files Changed

| File | Type | Change |
|------|------|--------|
| `app/services/attendance_service.py` | Modified | `get_by_session_with_details()` now uses single JOIN query instead of N+1 loop |
| `app/core/cache.py` | **New** | `CacheService` with TTL support (60s / 300s / 3600s) for session state, enrollment lists, course config |

### N+1 Fix Details
- **Before**: 1 query for records + N queries for students + 1 query for session + 1 query for course = O(N+3) queries
- **After**: Single `JOIN` query fetching Attendance, Student, Session, Course in one round-trip = O(1) queries

---

## Phase 7: Security Hardening

### Files Changed

| File | Type | Change |
|------|------|--------|
| `app/routers/v1/devices.py` | Modified | Added `verify_device_signature()` with HMAC-SHA256; device sync endpoints now require signature; device registration requires admin role |
| `app/routers/v1/auth.py` | Modified | Added `@limiter.limit("5/minute")` on login endpoint |
| `app/routers/v1/attendance.py` | Modified | Added `@limiter.limit("30/minute")` on checkin endpoint |

### Security Measures

| Measure | Details |
|---------|---------|
| Device signature verification | HMAC-SHA256 of `device_id:timestamp`; timestamp must be within 5 minutes |
| Admin-only device registration | `POST /api/v1/devices/` requires admin role via `require_role("admin")` |
| Login rate limiting | 5 attempts per minute per IP |
| Check-in rate limiting | 30 attempts per minute per IP |

---

## Phase 8: Observability

### Files Changed

| File | Type | Change |
|------|------|--------|
| `app/core/logger.py` | Modified | Replaced plain-text logger with JSON-structured logging; added `app_logger`, `security_logger`, `audit_logger` |
| `app/core/logger.py` | Modified | Added `log_info()`, `log_error()`, `log_warning()` helpers |
| `app/routers/v1/health.py` | **New** | `/health`, `/health/ready`, `/health/live` endpoints |
| `app/main.py` | Modified | Global exception handler uses structured logging; health router registration |

### Health Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Basic liveness: returns `{"status": "ok"}` |
| `GET /health/ready` | Readiness: checks DB connectivity with `SELECT 1` |
| `GET /health/live` | Process liveness: confirms process is running |

---

## Phase 9: Background Jobs

### Files Changed

| File | Type | Change |
|------|------|--------|
| `app/services/session_auto_close.py` | **New** | `auto_close_expired_sessions()`, `auto_activate_scheduled_sessions()`, `run_session_maintenance()` |
| `app/main.py` | Modified | Lifespan startup now runs `run_session_maintenance()` and spawns hourly background scheduler |

### Scheduler Behavior
- **Startup**: Runs `run_session_maintenance()` to activate/close any stale sessions
- **Background**: Every 1 hour, re-runs maintenance to close expired sessions
- **Shutdown**: All background tasks are cancelled gracefully

---

## Phase 10: Testing

### Files Changed/Created

| File | Type | Description |
|------|------|-------------|
| `tests/conftest.py` | Modified | Function-scoped DB fixture with rollback; SQLite in-memory for isolation |
| `tests/services/test_attendance_service.py` | **New** | `TestIdempotentCheckin`, `TestSessionAutoTransition`, `TestAttendanceValidator` |
| `tests/services/test_attendance_validator.py` | **New** | `TestAttendanceValidatorSession`, `TestAttendanceValidatorEnrolled` |
| `tests/api/v1/test_checkin_api.py` | **New** | `TestCheckinEndpoint`, `TestConcurrentCheckin` (10 concurrent students) |
| `tests/api/v1/test_attendance_api.py` | **New** | `TestAttendanceEndpoints` (auth requirement tests) |

### Test Coverage

| Test | Description |
|------|-------------|
| `test_duplicate_checkin_returns_existing` | Confirms idempotent behavior: 2nd check-in returns 1st record |
| `test_concurrent_checkins_all_create_records` | 10 students checking in concurrently to same session — all succeed |
| `test_scheduled_session_auto_activates` | Scheduled session auto-transitions to active on check-in |
| `test_validate_enrolled_returns_false_for_non_enrolled` | Validator correctly rejects non-enrolled students |
| `test_validate_enrolled_returns_true_for_enrolled` | Validator correctly accepts enrolled students |

---

## Summary

### Deliverables

| Phase | Files Created | Files Modified | Migrations |
|-------|--------------|----------------|-------------|
| 1 | 4 | 4 | 4 |
| 2 | 1 | 4 | 0 |
| 3 | 0 | 1 | 0 |
| 4 | 1 | 2 | 0 |
| 5 | 0 | 9 | 1 |
| 6 | 1 | 1 | 0 |
| 7 | 0 | 3 | 0 |
| 8 | 2 | 1 | 0 |
| 9 | 1 | 1 | 0 |
| 10 | 4 | 1 | 0 |
| **Total** | **15 new files** | **27 modified** | **5 migrations** |

### Migration Chain

```
0018_extend_courses_attendance_config
  └── 0019_add_production_constraints
        └── 0020_add_performance_indexes
              └── 0021_refactor_attendance_mode_enum
                    └── 0022_refactor_device_course_to_room
```

### To Apply Migrations

```bash
cd backend
alembic upgrade head
```

### To Run Tests

```bash
cd backend
pytest tests/ -v
```

### Breaking Changes to Communicate

1. **`attendance_mode` values**: `fixed` renamed to `preset` — existing courses will be migrated automatically by migration 0021
2. **`devices.course_id` removed**: Devices no longer bound to courses — device matching uses room field. Existing device records will need `room` set manually or via a data migration script
3. **Duplicate check-in**: Returns existing record (200) instead of conflict (409) — client code should handle both cases the same way
4. **Device sync `/api/v1/devices/{id}/sync`**: Now requires `X-Device-Signature` header for authentication
5. **Device registration**: Now requires admin authentication
