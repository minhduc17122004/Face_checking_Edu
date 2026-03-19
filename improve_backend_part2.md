You are a senior backend architect. Refactor and upgrade the backend (FastAPI + PostgreSQL + SQLAlchemy + Alembic) of an AI Face Recognition Attendance System to production-level quality.

The current system already has:
- users, teachers, students (students.id = INTEGER for backward compatibility)
- classrooms, classroom_students
- schedules, sessions, time_slots
- attendance (new) and attendance_records (legacy)
- devices
- face_embeddings

Your task is to CORRECT, EXTEND, and HARDEN the backend design.

---

# 🎯 OBJECTIVES

1. Align system with REAL Vietnamese university structure
2. Fix architectural flaws (time handling, offline support, anti-cheat)
3. Introduce missing domain layer: Academic Class (lớp chủ quản)
4. Keep backward compatibility with existing Flutter app
5. Make system production-ready

---

# 🧱 DOMAIN MODEL (MUST FOLLOW)

The system must clearly separate 3 layers:

1. Academic Layer (quản lý sinh viên)
2. Course Layer (lớp học phần)
3. Attendance Layer (điểm danh)

---

# 🆕 ADD NEW TABLE: ACADEMIC_CLASSES

Represents administrative class (e.g. 48K21.1)

Fields:
- id (UUID PK)
- code (UNIQUE) → e.g. "48K21.1"
- name (optional)
- faculty (optional)
- course_year (e.g. K21)
- advisor_id (FK → users.id, nullable)
- created_at

---

# 🔗 UPDATE STUDENTS

Add:
- academic_class_id (FK → academic_classes.id)

Rules:
- Each student belongs to exactly ONE academic class
- DO NOT store this as string
- DO NOT reuse classroom

---

# ⚠️ CRITICAL FIXES (MUST IMPLEMENT)

---

## 1. FIX SESSION TIME DESIGN

Current is incorrect:
- start_time TIME
- end_time TIME

Fix to:

- start_time TIMESTAMP
- end_time TIMESTAMP

Add:

- checkin_start_time TIMESTAMP
- checkin_end_time TIMESTAMP

Reason:
- TIME is not safe for real-world scheduling
- must support timezone and cross-day logic

---

## 2. RESTORE OFFLINE-FIRST ATTENDANCE

Update attendance table:

Add:
- checkin_time (device time)
- sync_time (server time)

This is REQUIRED to handle:
- offline tablet mode
- delayed sync

---

## 3. ENFORCE DEVICE-BASED ANTI-CHEAT

Enhance DEVICES:

Add:
- classroom_id (FK)
- last_active_at
- device_type
- ip_address

Backend MUST enforce:

- Device must belong to the same classroom as session
- Reject attendance if mismatch

---

## 4. IMPROVE FACE EMBEDDINGS

Keep JSONB but extend:

- user_id (FK → users.id)
- embedding_data (JSONB)
- is_active (boolean)
- device_id
- created_at

NOTE:
- Only users with role = "student" can register face (handled at service layer)
- Suggest migration to pgvector

---

## 5. ADD SOFT DELETE (IMPORTANT)

Add to:

- users
- students
- classrooms
- sessions
- attendance

Fields:
- is_deleted (boolean)
- deleted_at (timestamp)

---

## 6. ADD AUDIT FIELDS

Add:

- created_by
- updated_by

---

## 7. FIX ATTENDANCE STRUCTURE

Current:
- student_id

Keep for compatibility BUT ALSO:

- Add user_id (FK → users.id)

Eventually migrate logic to user_id

Keep constraint:
UNIQUE(session_id, student_id)

---

## 8. SESSION BUSINESS LOGIC SUPPORT

Add fields:

- checkin_start_time
- checkin_end_time

So system can:
- allow early check-in
- detect late arrival

---

# 📦 KEEP THESE (DO NOT BREAK)

- students.id must remain INTEGER
- attendance_records (legacy)
- existing API contract

---

# 📊 REQUIRED OUTPUT

Return:

1. Updated SQLAlchemy models (FULL)
2. Alembic migrations:
   - create academic_classes
   - alter students
   - alter sessions (timestamp)
   - alter attendance (add sync_time)
   - alter devices

3. ERD explanation (3-layer architecture)
4. Backend validation logic (pseudo code):
   - device validation
   - session check
   - attendance flow

5. Data migration plan (NO DATA LOSS)

---

# 🧠 BUSINESS RULES

- A student belongs to ONE academic class
- A student can join MULTIPLE classrooms
- A classroom has ONE teacher
- Attendance is tied to:
  - session
  - classroom
  - device

---

# 🚫 DO NOT DO

- Do NOT store academic class as string in students
- Do NOT merge academic_class with classroom
- Do NOT remove legacy tables
- Do NOT break Flutter compatibility

---

# 💡 BONUS (OPTIONAL)

- Suggest pgvector for embeddings
- Suggest Redis cache for session lookup
- Suggest WebSocket for real-time attendance

---

# FINAL GOAL

Design must be:
- clean
- scalable
- anti-cheat ready
- production-ready
