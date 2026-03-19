You are a Senior Backend Architect specializing in FastAPI, PostgreSQL, and scalable system design.

I have an existing backend system for an AI Face Recognition Attendance System with the following stack:

- FastAPI (async)
- PostgreSQL
- SQLAlchemy 2.x (async ORM)
- Alembic migrations
- JWT authentication
- Clean Architecture (Router → Service → Repository)

The system already includes:
- Users, Students, Teachers
- Classroom, Schedule, Session
- Attendance (new session-based system)
- Legacy attendance system (to be removed)
- Face embeddings (JSONB)
- Device management
- AcademicClass (homeroom class)

---

# 🎯 YOUR TASK

Refactor and upgrade the backend to be *production-ready, consistent, and scalable*, focusing on:

---

# 1. REMOVE ARCHITECTURAL INCONSISTENCIES

## 1.1 Unify Attendance System
- Remove legacy attendance completely
- Keep ONLY session-based attendance
- Ensure:
  - UNIQUE(session_id, student_id)
  - Strong foreign key constraints
- Update all services and repositories accordingly

---

## 1.2 Fix Identity Model (VERY IMPORTANT)

Current problem:
- attendance has both student_id and user_id
- face_embeddings has both student_id and user_id

Refactor to:

- users = ONLY authentication identity
- students / teachers = profile tables

Apply rules:
- Attendance → ONLY use student_id
- Remove user_id from attendance
- FaceEmbedding → ONLY use student_id

---

## 1.3 Remove Misused Fields

- Remove usage of job_title in Student
- Fully migrate to:
  - academic_class_id (FK → academic_classes)

---

# 2. DATABASE IMPROVEMENTS

## 2.1 Add Critical Indexes

Add indexes for performance:

- attendance(session_id, student_id)
- attendance(checkin_time)
- face_embeddings(student_id)
- sessions(classroom_id, start_time)
- classroom_students(classroom_id, student_id)

---

## 2.2 Prepare for Vector Search (Future AI Scaling)

Refactor face_embeddings:

- Replace JSONB with pgvector:
  embedding vector(128)

- Add index:
  USING ivfflat (embedding vector_cosine_ops)

---

## 2.3 Enforce Soft Delete Properly

- Ensure ALL queries exclude:
  is_deleted = TRUE

- Implement:
  - BaseRepository filter
  OR
  - SQLAlchemy global query filter

---

# 3. SERVICE LAYER IMPROVEMENT

## 3.1 Introduce UseCase Layer (IMPORTANT)

Refactor business logic:

FROM:
- Services handling everything

TO:
- UseCase layer orchestrates logic

Example:

CheckinUseCase:
- validate session
- validate device
- check duplicate attendance
- call repository

Services become helpers only

---

## 3.2 Improve Anti-Cheat

Ensure AntiCheatService validates:

- Device belongs to classroom
- Session is ACTIVE
- Checkin within allowed time window
- No duplicate attendance

---

# 4. AUTHENTICATION UPGRADE

## 4.1 Implement Refresh Token Flow

Add:

- access_token (15 minutes)
- refresh_token (7 days)

Create:
- /auth/refresh endpoint

Store refresh tokens in DB:
- user_id
- device_id
- expires_at
- revoked flag

---

## 4.2 Implement RBAC (Role-Based Access Control)

Add decorator:

@require_role("admin")
@require_role("teacher")

Apply to:
- classroom management
- student assignment
- device management

---

## 4.3 Device Authentication (IMPORTANT)

Upgrade device model:

- Each device has:
  - device_secret
  - API key / token

Flow:
- Device must authenticate before sending attendance

---

# 5. API STANDARDIZATION

## 5.1 Add Versioning

Refactor all routes:

/api/v1/auth
/api/v1/users
/api/v1/classes
/api/v1/sessions
/api/v1/attendance

---

## 5.2 Remove /attendance/new

Rename to:
/attendance

---

# 6. ERROR HANDLING & STABILITY

## 6.1 Add Global DB Exception Handler

Handle:

- IntegrityError
- ForeignKeyViolation
- UniqueViolation

Return:
- Clean API error responses

---

## 6.2 Fix get_db Transaction Handling

Ensure:

- rollback on error
- no silent commit issues

---

# 7. CLEANUP & CONSISTENCY

- Remove unused imports
- Fix naming inconsistencies
- Ensure all schemas match models
- Ensure typing works for Python 3.8+

---

# 8. OUTPUT REQUIRED

Generate:

1. Updated SQLAlchemy models
2. Updated repositories
3. Updated services + new UseCase layer
4. Auth module with refresh token
5. RBAC implementation
6. Device authentication logic
7. Alembic migration scripts
8. Clean API routes (v1)
9. Clear folder structure

---

# IMPORTANT CONSTRAINTS

- Must remain compatible with existing Flutter app where possible
- Student.id must remain INTEGER
- Use async/await everywhere
- Follow clean architecture strictly
- Code must be production-ready, not demo-level

---

# EXPECTED RESULT

A clean, scalable backend with:

- Single source of truth
- No duplicated systems
- Strong security
- Ready for scaling to thousands of users/devices
