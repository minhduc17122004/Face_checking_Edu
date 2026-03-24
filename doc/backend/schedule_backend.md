---
name: Join time_slot into schedule API response
overview: Modify the backend so that `GET /api/v1/schedules` returns schedules WITH their related time_slot object joined from the DB. The Flutter frontend's `Schedule.fromJson()` already handles parsing `time_slot`, so no Flutter changes are needed.
todos:
  - id: backend-schema
    content: "Update schedule schema: add ScheduleOutV2 with time_slot, fix ScheduleWithTimeSlot typing"
    status: completed
  - id: backend-repo
    content: Update ScheduleRepository.list() to eager-load time_slot via joinedload
    status: completed
  - id: backend-router
    content: Update v1/schedules.py router to return ScheduleWithTimeSlot (with time_slot) in GET and POST
    status: completed
isProject: false
---

## Backend changes (3 files)

### 1. `backend/app/schemas/v1/schedule.py`

- Change `ScheduleWithTimeSlot.time_slot` from `dict | None` to `TimeSlotOut | None` for proper typing.
- Add a new `ScheduleOutV2` response model that includes the joined `time_slot`.

### 2. `backend/app/repositories/schedule_repository.py`

- In the `list()` method, add a `joinedload(Schedule.time_slot)` so that eager-loading is used.
- Import `selectinload` / `joinedload` from SQLAlchemy and the `TimeSlot` model.
- The repository's `list()` must return schedules with `schedule.time_slot` hydrated.

### 3. `backend/app/routers/v1/schedules.py`

- `GET /` — switch from `ScheduleOut` to `ScheduleWithTimeSlot` (or a new `ScheduleOutV2`) so that the `time_slot` field is included in the JSON response.
- `POST /` — also return `ScheduleWithTimeSlot` so newly created schedules include the slot.

---

## Frontend — no changes required

The existing `Schedule.fromJson()` already handles `json['time_slot']` correctly:

```5:33:lib/entities/schedule.dart
  factory Schedule.fromJson(Map<String, dynamic> json) {
    TimeSlot? ts;
    if (json['time_slot'] != null) {
      ts = TimeSlot.fromJson(json['time_slot'] as Map<String, dynamic>);
    }
    return Schedule(
      ...
      timeSlot: ts,
      ...
    );
  }
```

And `_ScheduleCard` already uses `schedule.timeSlot?.displayName` and `schedule.timeSlot?.displayTime`, so once the backend returns the joined object, the UI will display period number and time range automatically.

---

## Verification steps

1. Test `GET /api/v1/schedules?course_id=<uuid>` returns an `items[].time_slot` object.
2. Verify the Flutter schedule list shows the period name (e.g. "Tiết 3") and time range (e.g. "08:50 - 09:40") instead of the fallback "Tiết 3".
3. Verify adding a new schedule also returns `time_slot` in the response.

