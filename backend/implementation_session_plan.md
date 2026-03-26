Dưới đây là phiên bản **đã chốt (refined + production-ready)** — giữ nguyên cấu trúc plan của bạn nhưng bổ sung các cải tiến quan trọng (state machine, validation, UI logic, edge cases).

Bạn có thể **copy trực tiếp vào file .md**:

---

````md
# EDU Attendance Session Management Refactor

This plan outlines the changes needed to support manual opening and closing of attendance sessions for teachers and admins, restricted to "flexible" attendance mode and specific time windows.

---

## User Review Required

> [!IMPORTANT]
> The manual open/close functionality is enforced ONLY for `FLEXIBLE` mode.
> `FIXED` mode sessions are automatically controlled by time.

---

## Core Design (Finalized)

### Session State Model

Internal (DB):
- `scheduled`
- `active`
- `closed`

API/UI (derived):
- `NOT_OPEN`      (before start time)
- `CAN_OPEN`      (within time window, not opened yet)
- `OPEN`          (session is active)
- `CLOSED`        (session closed)

### Action Flags (IMPORTANT)

Instead of adding new states like "can close", use:

- `canOpen`
- `canClose`

```pseudo
canOpen  = (state == CAN_OPEN) AND mode == FLEXIBLE
canClose = (state == OPEN)     AND mode == FLEXIBLE
````

---

## Proposed Changes

---

### Backend Refinement

#### [MODIFY] sessions.py

* Update `open_session` and `close_session`:

##### Open session validation

```pseudo
if mode != FLEXIBLE → reject
if now < start_time → reject
if now > end_time → reject
if state != CAN_OPEN → reject
if previous session not closed:
    if previous.end_time < now:
        auto-close previous
    else:
        reject
```

##### Close session validation

```pseudo
if mode != FLEXIBLE → reject
if state != OPEN → reject
```

---

#### Auto state handling (IMPORTANT)

For FIXED mode:

```pseudo
if now < start_time → NOT_OPEN
if now ∈ [start_time, end_time] → OPEN
if now > end_time → CLOSED
```

For FLEXIBLE mode:

```pseudo
if now < start_time → NOT_OPEN
if now ∈ [start_time, end_time] AND not opened → CAN_OPEN
if opened → OPEN
if closed → CLOSED
```

---

#### Auto-close safeguard

```pseudo
if state == OPEN AND now > end_time:
    auto-close session
```

---

#### [MODIFY] get_session_status

Return:

```json
{
  "status": "CAN_OPEN | OPEN | CLOSED | NOT_OPEN",
  "mode": "FIXED | FLEXIBLE",
  "canOpen": true/false,
  "canClose": true/false
}
```

---

#### [ADD] GET /sessions/teacher/active-or-next

Return:

* current session if exists
* else next upcoming session
* include:

  * status
  * mode
  * canOpen
  * canClose

---

#### [MODIFY] session_repository.py

* Add `get_upcoming_sessions_by_teacher`
* Ensure ordering by start_time ASC

---

#### [MODIFY] attendance_service.py

* Add `get_active_or_next_session_for_teacher`
* Ensure deterministic selection:

  * prioritize active session
  * fallback to nearest upcoming

---

#### Audit Logging (NEW)

Log all actions:

```text
userId
role
sessionId
action (OPEN/CLOSE)
timestamp
result (success/reject)
reason
```

---

### Frontend Implementation

---

#### UI Structure (UPDATED)

Split sessions into 3 tabs:

1. **Chưa diễn ra**

   * `NOT_OPEN`

2. **Đang diễn ra**

   * `CAN_OPEN`
   * `OPEN`

3. **Đã đóng**

   * `CLOSED`

---

#### ON/OFF Toggle Logic

Show toggle ONLY when:

```pseudo
mode == FLEXIBLE AND status ∈ (CAN_OPEN, OPEN)
```

Mapping:

| UI  | Backend |
| --- | ------- |
| ON  | OPEN    |
| OFF | CLOSED  |

---

#### Button / Toggle State

```pseudo
if !canOpen → disable ON
if !canClose → disable OFF
```

---

#### [MODIFY] session.dart

* Add:

  * `attendanceMode`
  * `status`
  * `canOpen`
  * `canClose`

---

#### [NEW] edu_session_quick_access.dart

Display:

* current session
* status label
* ON/OFF toggle (if FLEXIBLE)
* disabled state if not allowed

---

#### [MODIFY] home_page.dart

* Add Quick Access widget for teacher/admin

---

#### [MODIFY] room_session_page.dart

* Group sessions by 3 tabs
* Disable actions if:

  * mode != FLEXIBLE
  * or canOpen/canClose = false

---

## Verification Plan

---

### Automated Tests

* open_session:

  * reject FIXED mode
  * reject outside time window
  * reject invalid state
  * auto-close previous session

* close_session:

  * reject if not OPEN

* get_session_status:

  * correct mapping for all time ranges

* active-or-next API:

  * returns correct session context

---

### Manual Verification

1. Login as Teacher
2. Open Home → Quick Access
3. Verify:

   * correct status (NOT_OPEN / CAN_OPEN / OPEN / CLOSED)
4. Test FLEXIBLE:

   * toggle ON → session OPEN
   * toggle OFF → session CLOSED
5. Test FIXED:

   * no toggle
   * auto status change
6. Verify:

   * cannot open before time
   * cannot open if previous not closed (or auto-closed)
7. Verify auto-close when session ends

---

## Final Notes

* No new state like "CAN_CLOSE" is introduced → handled via flags
* Backend is the single source of truth
* UI is purely driven by status + flags
* System is resilient to:

  * missed close actions
  * delayed operations
  * incorrect user interaction

````

---

