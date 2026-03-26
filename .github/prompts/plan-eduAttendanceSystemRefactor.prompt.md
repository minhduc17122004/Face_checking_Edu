## Plan: EDU Attendance Refactor with Room Binding

Refactor EDU attendance by preserving the HRM face-recognition pipeline and moving all attendance/session decisions to backend. Implement tenant-aware room binding on frontend, augment check-in queue payload with room/device/timestamp, add backend room+timestamp session mapping with grace windows and idempotent duplicate handling, and expose teacher/admin session controls (open/close/status) with strict transition guards. Use compatibility mode to accept legacy + new payloads during migration.

## Additional Production Safeguards

- Add fallback handling when no session is mapped (return explicit error + log context).
- Enforce backend validation for deviceId ↔ roomId binding to prevent spoofed room data.
- Introduce time drift tolerance between client and server timestamps.
- Define clear time window: [start_time - early_grace, end_time + late_grace].
- Auto-close previous session if not closed when next session starts.
- Enhance logging with decision trace (mapping_reason, rejection_reason, mode).
- (Optional) Add short-lived cache for session lookup by roomId to reduce DB load.

**Steps**
1. Phase 1: Baseline and compatibility contract
2. Freeze current HRM recognition boundaries and explicitly mark non-touch modules (FaceNative capture/verify path, camera flow, Workmanager bootstrap signatures) so refactor is constrained to attendance payload/session logic only.
3. Define and document dual-accept check-in API contract (legacy and minimal payload) with canonical normalized server DTO: student_id, room_id, timestamp (client time), device_id; preserve existing fields as optional/deprecated for transition. *Blocks phases 3-5*
4. Phase 2: Frontend room binding and payload enrichment
5. Add tenant-aware active room persistence using SharedPreferences key format active_room-{tenantId}, plus optional display-name companion key; expose get/set methods in LocalService abstraction. *Can run parallel with step 8*
6. Add/adjust room selection UX to radio-list + confirmation dialog, enforce selection gate at app start (if no active room then route to room selection), and surface active room prominently in EDU check-in and room-session UIs.
7. Extend local queued check-in entity/DTO path used by EDU flow to carry roomId + deviceId + timestamp while keeping backwards compatibility for existing queued items (nullable migration handling and fallback read path).
8. Update EDU check-in sync flow to submit normalized payload to backend from local queue, ensuring no client-side session resolution logic is introduced; keep current retry/Workmanager strategy.
9. Phase 3: Backend data model and mapping engine
10. Add/extend schema for session mapping and controls: room-aware attendance config precedence (session override > course default), grace period storage, and any missing indexes for room+time lookups. Create Alembic migration with reversible downgrade. *Depends on step 3*
11. Implement deterministic session resolver by roomId + client timestamp (timezone-aware UTC normalization) with valid-window rule [start_time, end_time + grace]; if no valid session, return domain-specific rejection reason.
12. Enforce session lifecycle rules in service layer: CLOSED sessions reject check-in; sequential transition guard (next session cannot OPEN until previous CLOSED); attendance check-in allowed only when resolved session is OPEN (or FIXED auto-open behavior marks eligible session open by time).
13. Keep existing internal statuses (scheduled/active/closed) and expose mapped API status view NOT_OPEN/CAN_OPEN/OPEN/CLOSED for client consumption.
14. Phase 4: APIs and permissions
15. Extend attendance check-in endpoint contract to accept minimal payload and legacy payload; centralize normalization + validation + idempotency handling in service layer.
16. Add session-control endpoints: POST /sessions/{id}/open, POST /sessions/{id}/close, GET /sessions/{id}/status; gate by teacher/admin roles and transition validity.
17. Add/adjust repository queries for duplicate prevention with idempotent success semantics when (student_id, session_id) already exists.
18. Add structured audit logs for deviceId, roomId, studentId, timestamp, mapped_session_id, decision/status, and rejection reason.
19. Phase 5: Teacher dashboard integration (scoped)
20. Add teacher/admin-only session list section with mapped statuses and enable/disable open/close actions based on backend status response; keep scope limited to status + controls (no new summary/student-list redesign in this phase).
21. Wire open/close actions to new APIs and refresh status optimistically with rollback on failure.
22. Phase 6: Migration rollout and verification
23. Add feature toggles/config flags for compatibility window (dual payload acceptance) and log warnings on legacy requests to support gradual client rollout.
24. Validate offline behavior with delayed sync: queued records map to sessions by original client timestamp, duplicates remain idempotent, and closed/invalid-session rejections are logged clearly.
25. Execute backend + frontend verification suite and targeted manual QA scenarios before enabling strict mode (optional hard switch to minimal payload only).

**Relevant files**
- face_time_keeping/lib/entities/check_in_out.dart — add roomId/deviceId fields for HRM-aligned entity path if still used by EDU sync serialization.
- face_time_keeping/lib/entities/pending_edu_check_in.dart — extend queued EDU payload model with room/device metadata and migration-safe defaults.
- face_time_keeping/lib/pages/edu_checking/bloc/edu_checking_bloc.dart — keep FaceNative verify path intact; inject room/device payload enrichment and sync request normalization.
- face_time_keeping/lib/data/local/keychain/shared_prefs_key.dart — add tenant-aware room keys.
- face_time_keeping/lib/data/local/local_service.dart — add room persistence API and tenant key formatting reuse.
- face_time_keeping/lib/pages/room/room_selection_page.dart — radio selection + confirmation + persist active room.
- face_time_keeping/lib/pages/edu_checking/edu_checking_page.dart — show active room prominently and selection-required guard state.
- face_time_keeping/lib/pages/room/room_session/room_session_page.dart — show active room/status context for teacher flow.
- face_time_keeping/lib/data/remote/attendance_checkin_service.dart — send minimal payload contract (plus compatibility fields when present).
- face_time_keeping/backend/app/routers/v1/attendance.py — dual-accept check-in API and normalization entrypoint.
- face_time_keeping/backend/app/schemas/v1/attendance_checkin.py — request/response schema updates for minimal payload and status/rejection details.
- face_time_keeping/backend/app/services/attendance_service.py — session resolver integration, lifecycle checks, idempotent check-in behavior.
- face_time_keeping/backend/app/services/anti_cheat_service.py — align window validation to room+timestamp/grace and mode precedence.
- face_time_keeping/backend/app/services/attendance_config_service.py — FIXED/FLEXIBLE precedence (session > course) and grace retrieval.
- face_time_keeping/backend/app/routers/v1/sessions.py — open/close/status endpoints and role checks.
- face_time_keeping/backend/app/models/session.py — lifecycle/status helpers and transition constraints.
- face_time_keeping/backend/app/models/attendance_config.py — mode/grace schema updates.
- face_time_keeping/backend/app/models/attendance.py — duplicate guarantee and any added indexes.
- face_time_keeping/backend/app/repositories/attendance_repository.py — idempotent fetch/create logic by (session_id, student_id).
- face_time_keeping/backend/alembic/versions/<new_revision>.py — schema migration for config/status/index updates.

**Verification**
1. Backend unit/service tests: session mapping by room+timestamp, grace window boundary checks, CLOSED-session rejection, sequential open/close guard, FIXED/FLEXIBLE precedence.
2. Backend API tests: POST /attendance/check-in with minimal payload and legacy payload; duplicate submissions return idempotent success; role-based access on open/close.
3. DB verification: unique constraint (student_id, session_id) remains effective; new indexes exist and are used by EXPLAIN for room+time query path.
4. Frontend integration tests: app-start room-required flow, room selection confirmation persistence per tenant, active room display, check-in queue payload contains room/device/timestamp.
5. Offline QA: disable network, perform check-ins, restart app, re-enable network, verify Workmanager sync maps by original timestamp and handles duplicate/closed-session responses correctly.
6. Regression QA: HRM recognition/camera flow unchanged (no new camera streaming path, no FaceNative behavior regression).

**Decisions**
- Use dual payload compatibility during transition, then optional strict mode later.
- Keep internal backend statuses and map to NOT_OPEN/CAN_OPEN/OPEN/CLOSED at API/UI layer.
- Attendance mode source-of-truth: both levels with precedence session override > course default.
- Tenant room key: active_room-{tenantId}; include display label key for UX only.
- Teacher dashboard scope in this phase: status list + open/close controls only.
- Explicitly excluded in this phase: major redesign of student list/summary widgets, camera/recognition algorithm changes, and non-attendance domain refactors.

**Further Considerations**
1. Backfill strategy for pre-existing queued records without roomId: either reject with actionable sync error or infer from currently bound room at sync time (recommended: infer once with audit flag to reduce data loss).
2. API versioning approach: keep same endpoint with tolerant schema vs introducing /v2/check-in (recommended: same endpoint + schema evolution for faster rollout).
3. Operational observability: add dashboard counters for mapped-success, no-session, closed-session, duplicate-idempotent, and unauthorized-device outcomes.
