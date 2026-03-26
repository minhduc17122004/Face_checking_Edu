---
name: Phase 9 Production Ready
overview: "Finalize Phase 9 Device-based Attendance Management to production-ready state: fix data consistency, harden device authorization, add audit logging, enhance APIs, update Flutter UI with polling, and add indexes/tests."
todos:
  - id: p9-1
    content: "Backend: Remove room_id from Attendance model"
    status: completed
  - id: p9-2
    content: "Backend: Harden device authorization in AttendanceService"
    status: completed
  - id: p9-3
    content: "Backend: Update status calculation to early/on_time/late"
    status: completed
  - id: p9-4
    content: "Backend: Create AttendanceAuditLog model and service"
    status: completed
  - id: p9-5
    content: "Backend: Add can_checkin to RoomSessionResponse"
    status: completed
  - id: p9-6
    content: "Backend: Update AttendanceSummaryResponse with early/on_time counts"
    status: completed
  - id: p9-7
    content: "Backend: Create alembic migration 0030"
    status: completed
  - id: p9-8
    content: "Flutter: Update AttendanceRecordUI with isOnTime/isEarly"
    status: completed
  - id: p9-9
    content: "Flutter: Add 5-second polling to AttendanceCheckinPage"
    status: completed
  - id: p9-10
    content: "Flutter: Update summary card with 5 categories"
    status: completed
  - id: p9-11
    content: "Flutter: Add canCheckin field to RoomSession and button control"
    status: completed
  - id: p9-12
    content: Write backend unit tests for Phase 9
    status: completed
isProject: false
---

# Phase 9: Production-Ready Implementation Plan

# Final Adjustments (Production Hardening)

Before proceeding, apply the following critical adjustments to ensure production readiness:

- Enforce **DB-level safety**: keep `UNIQUE(student_id, session_id)` and handle `IntegrityError` for idempotent check-in.
- Compute `can_checkin` **only from time window**, not `session.status`.
- Ensure **active_device lock is atomic** (`UPDATE ... WHERE active_device_id IS NULL`).
- Standardize summary:
  - `present = early + on_time + late`
  - `absent = total_enrolled - total_checked_in`
- Add **pagination** for large datasets (`checkins`, `history`).
- Harden **device authorization**: must be `ACTIVE`, `APPROVED`, and room-matched (or global).
- Add and use **audit logs** for all attendance actions.
- Optimize **polling** (only when active screen, 5–10s interval).
- Ensure **indexes** and `deleted_at IS NULL` are consistently applied.
- Add **concurrent check-in test case** to validate race condition handling.

Goal: eliminate race conditions, guarantee data consistency, and ensure the system is production-ready.

## Gap Analysis (Current State vs Requirements)


| Requirement                               | Status                    | Action Needed                             |
| ----------------------------------------- | ------------------------- | ----------------------------------------- |
| Attendance Config (early/late allowance)  | ✅ Done                    | None                                      |
| `get_effective_config()`                  | ✅ Done                    | None                                      |
| Time Window Logic                         | ✅ Done                    | None                                      |
| `UNIQUE(student_id, session_id)`          | ✅ Done                    | None                                      |
| Transaction-safe check-in                 | ✅ Done (distributed lock) | None                                      |
| `status: early/on_time/late`              | ⚠️ Partial                | Add "early" and "on_time" status          |
| Remove `room_id` from `Attendance`        | ❌ Not Done                | **Critical — remove it**                  |
| Device authorization in service           | ❌ Not Done                | **Critical — call `check_device_access`** |
| `can_checkin` in RoomSessionResponse      | ❌ Not Done                | Add field                                 |
| Audit log table                           | ❌ Not Done                | Create table + use it                     |
| Active Device Lock                        | ❌ Not Done                | Add optional feature                      |
| Polling in Flutter                        | ❌ Not Done                | Add Timer polling                         |
| Index `(room_id, start_time)` on sessions | ⚠️ Partial                | Verify/add                                |
| Unit tests                                | ❌ Not Done                | Write tests                               |
| `minutes_diff` in Attendance model        | ✅ Done                    | None                                      |
| Flutter `isOnTime`                        | ❌ Missing                 | Add to entity                             |


---

## Backend Changes

### 1. Remove `room_id` from Attendance model

**File:** `backend/app/models/attendance.py`

Remove the `room_id` column and relationship from `Attendance`. Room must always be derived from `session → course → room`. This eliminates data redundancy and ensures consistency.

```python
# REMOVE these lines:
room_id: Mapped[Optional[uuid.UUID]] = mapped_column(
    UUID(as_uuid=True),
    ForeignKey("rooms.id", ondelete="SET NULL"),
    nullable=True,
    index=True,
)
room: Mapped[Optional["Room"]] = relationship(
    "Room", back_populates="attendance_records"
)
```

Also remove `room_id` and `minutes_diff` from the `create()` call in `AttendanceRepository` and the service.

---

### 2. Harden Device Authorization in AttendanceService

**File:** `backend/app/services/attendance_service.py`

**Critical fix:** `create_attendance()` and `manual_checkin()` must call `self.device_auth.check_device_access()` BEFORE processing check-in. Currently it's initialized but never called.

```python
# Add at the start of create_attendance() after session validation:
if device_id:
    ok, msg = await self.device_auth.check_device_access(device_id, session_id)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Device authorization failed: {msg}",
        )
```

Also remove the old `validate_device_for_session` anti-cheat call since it's superseded.

---

### 3. Update Status Calculation — "early" / "on_time" / "late"

**File:** `backend/app/services/attendance_service.py`

Update the status calculation in `create_attendance()`:

```python
# Phase 9 enhanced status calculation:
calculated_minutes_diff = int(delta.total_seconds() / 60)

if calculated_minutes_diff < 0:
    auto_status = "early"
elif calculated_minutes_diff == 0:
    auto_status = "on_time"
else:
    auto_status = "late"
```

Also update `AttendanceSummaryResponse` schema to include `early` and `on_time` counts.

---

### 4. Create Attendance Audit Log

**File:** `backend/app/models/attendance_audit_log.py` (NEW)

```python
class AttendanceAuditLog(Base):
    __tablename__ = "attendance_audit_logs"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    session_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    device_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), nullable=True)
    action: Mapped[str] = mapped_column(String(20), nullable=False)  # "checkin", "manual", "delete"
    old_status: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    new_status: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

**File:** `backend/app/services/audit_service.py`

Add `log_attendance_action()` method that writes to the new audit table. Update `create_attendance()` to call it.

---

### 5. Add `can_checkin` to RoomSessionResponse

**File:** `backend/app/schemas/v1/room_session.py`

Add `can_checkin: bool` field:

```python
can_checkin: bool = Field(
    description="Whether attendance can currently be checked in for this session"
)
```

**File:** `backend/app/routers/v1/room_sessions.py`

Update `_build_room_session_list()` to compute `can_checkin`:

```python
from datetime import timedelta
effective_start = session.start_time - timedelta(minutes=early_allowance)
effective_end = session.end_time + timedelta(minutes=late_allowance) if session.end_time else None
now = datetime.now(timezone.utc)
can_checkin = (
    session.status == "active" and
    effective_start <= now <= (effective_end or datetime.max)
)
```

Also need to resolve `early_allowance` and `late_allowance` from session's `attendance_config` or defaults.

---

### 6. Update AttendanceSummaryResponse Schema

**File:** `backend/app/schemas/v1/attendance_checkin.py`

```python
class AttendanceSummaryResponse(BaseModel):
    session_id: uuid.UUID
    course_name: str
    total_enrolled: int
    total_checked_in: int
    present: int      # renamed: was "present" = on_time count
    early: int         # NEW: checked in early
    on_time: int       # NEW: checked in exactly on time
    late: int
    absent: int
    attendance_rate: float
```

Update `AttendanceService.get_enhanced_summary()` to compute `early`, `on_time`, `late` counts separately using `minutes_diff`.

---

### 7. Alembic Migration — Update 0029

**File:** `backend/alembic/versions/0029_add_device_attendance_tables.py`

Since `0029` is already applied, create a new migration `0030_finalize_phase9.py`:

- Drop `room_id` column from `attendance` table (after verifying cascade)
- Create `attendance_audit_logs` table
- Add `status` values index to cover `early`/`on_time`/`late`
- Ensure `INDEX ix_attendance_session_student` exists on `(session_id, student_id)`

---

### 8. Optional: Active Device Lock

**File:** `backend/app/models/session.py`

Add field:

```python
active_device_id: Mapped[Optional[uuid.UUID]] = mapped_column(
    UUID(as_uuid=True),
    ForeignKey("devices.id", ondelete="SET NULL"),
    nullable=True,
)
```

Rule: Only the first device to check-in becomes `active_device_id`. Subsequent check-ins from different devices are rejected unless `device.is_global=true`.

---

### 9. Update DeviceAuthorizationService

**File:** `backend/app/services/device_authorization_service.py`

Refine `check_device_access()` to:

- Check `device.status == "ACTIVE"` ✅
- Check `request.status == "APPROVED"` ✅
- Check room match or `is_global` ✅
- **Add:** Check that approved request hasn't expired (if `reviewed_at` + 30 days < now)

---

### 10. Add Production Indexes

**File:** `backend/alembic/versions/0030_finalize_phase9.py`

```sql
CREATE INDEX ix_attendance_session_student ON attendance(session_id, student_id);
CREATE INDEX ix_attendance_checkin_time ON attendance(checkin_time);
CREATE INDEX ix_sessions_room_start ON sessions(course_id, start_time);
CREATE INDEX ix_device_requests_status ON device_requests(status);
CREATE INDEX ix_attendance_audit_session ON attendance_audit_logs(session_id);
```

---

## Flutter Changes

### 11. Update AttendanceRecordUI entity

**File:** `lib/entities/attendance_record_ui.dart`

- Add `isOnTime` getter: `status == 'on_time'`
- Add `isEarly` getter: `status == 'early'`
- Rename `isPresent` to `isPresentOrOnTime` or keep as-is but handle `early`/`on_time` separately

### 12. Add Polling to AttendanceCheckinPage

**File:** `lib/pages/attendance_checkin/attendance_checkin_page.dart`

Add `Timer` that polls summary and checkins every 5 seconds:

```dart
class _AttendanceCheckinViewState extends State<_AttendanceCheckinView> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      widget.bloc.loadSessionCheckins(widget.session.id);
      widget.bloc.loadSessionSummary(widget.session.id);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
```

### 13. Update Summary Card — Show 5 categories

**File:** `lib/pages/attendance_checkin/attendance_checkin_page.dart`

Update `_buildSummaryCard()` to show: early, on_time, late, checked_in, absent. Update `AttendanceCheckinSummary` in `attendance_checkin_service.dart` to include `early` and `on_time` fields.

### 14. Update Record Item — Show early/on_time/late icons

**File:** `lib/pages/attendance_checkin/attendance_checkin_page.dart`

Update `_buildRecordItem()`:

- `isEarly` → green clock icon, label "Sớm"
- `isOnTime` → green check icon, label "Đúng giờ"
- `isLate` → orange clock icon, label "Trễ +Xm"

### 15. Update RoomSession entity — Add canCheckin

**File:** `lib/entities/room_session.dart`

Add `canCheckin` field from API response. Update session card to disable check-in button when `canCheckin=false`.

### 16. Enable/disable check-in button in RoomSessionPage

**File:** `lib/pages/room/room_session_page.dart`

Wrap the session card's `InkWell` with a check that `session.canCheckin == true`. If `false`, show a greyed-out button or navigate to a read-only view instead.

---

## Test Cases

### Backend tests (`backend/tests/test_attendance_phase9.py`) (NEW)

```python
# 1. Check-in within time window → success
# 2. Check-in before early_allowance → fail with "Too early"
# 3. Check-in after late_allowance → fail with "Too late"
# 4. Duplicate check-in → idempotent, returns existing record
# 5. Device not approved → 403 Forbidden
# 6. Device APPROVED but wrong room (not global) → 403
# 7. Global device → can access any room
# 8. Status: early (delta < 0), on_time (delta == 0), late (delta > 0)
# 9. room_id NOT stored in attendance (derived from session)
# 10. Audit log entry created for each check-in
```

---

## File Summary

```
Backend:
  models/attendance.py                    → REMOVE room_id
  models/attendance_audit_log.py          → NEW audit table
  services/attendance_service.py          → call device_auth, fix status, use audit
  services/device_authorization_service.py → refine checks
  schemas/v1/attendance_checkin.py        → add early/on_time to summary
  schemas/v1/room_session.py               → add can_checkin
  routers/v1/room_sessions.py              → compute can_checkin
  alembic/versions/0030_finalize_phase9.py → NEW migration

Flutter:
  entities/attendance_record_ui.dart       → add isOnTime, isEarly
  data/remote/attendance_checkin_service.dart → add early/on_time to summary
  pages/attendance_checkin/attendance_checkin_page.dart → add polling, update UI
  pages/room/room_session_page.dart        → canCheckin button control
  entities/room_session.dart               → add canCheckin field
  pages/attendance_checkin/bloc/attendance_checkin_bloc.dart → polling logic

Tests:
  backend/tests/test_attendance_phase9.py   → NEW test file
```

