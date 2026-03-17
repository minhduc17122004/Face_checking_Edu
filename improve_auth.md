You are a senior backend engineer and system architect.
Your task is to implement a complete backend for an **AI Face Recognition Attendance System for universities in Vietnam**.

The backend must be designed to support:

1. Tablet kiosk application for face registration and attendance.
2. Mobile application for students and teachers.
3. A simulated academic management system because the real university academic system is not accessible.

Use the following technology stack:

* **Python FastAPI**
* **PostgreSQL**
* **SQLAlchemy ORM**
* **Alembic for migrations**
* **JWT Authentication**
* **Pydantic models**
* **Modular clean architecture**
* Optional: Redis for caching

The project must be structured in a scalable production-like architecture.

---

# System Context

This system is designed for universities where:

* Students register courses each semester.
* Each course creates a **course section (class section)**.
* Each section has:

  * subject
  * teacher
  * room
  * schedule (based on time slots / periods).
* Each classroom has **one tablet kiosk** used for:

  * face registration
  * attendance check-in.

Students and teachers use a **mobile application** to view attendance information.

Since we cannot access the real university academic system, the backend must include a **simulated academic module**.

---

# Core Modules

The backend must contain three main modules:

1. **Authentication Module**
2. **Academic Module (Simulated University System)**
3. **Attendance Module**

---

# Database Design

Implement PostgreSQL schema with SQLAlchemy models.

### Users

Support roles:

* student
* teacher
* admin

Fields:

* id
* email
* password_hash
* role
* created_at

---

### Students

* id
* student_code
* full_name
* class_name
* faculty

---

### Teachers

* id
* full_name
* department

---

### Subjects

* id
* subject_name
* credits

---

### Course Sections (Class Sections)

Represents a subject taught by a teacher.

Fields:

* id
* subject_id
* teacher_id
* room
* semester

---

### Enrollments

Students registered in a course section.

Fields:

* id
* student_id
* section_id

---

### Time Slots

Vietnamese universities use periods (tiết học).

Example:

1 → 07:30 – 08:20
2 → 08:20 – 09:10
3 → 09:10 – 10:00

Fields:

* id
* slot_number
* start_time
* end_time

---

### Schedule

Defines weekly class schedule.

Fields:

* id
* section_id
* day_of_week
* start_slot
* end_slot

---

### Devices

Tablet kiosks used for attendance.

Fields:

* id
* device_code
* room
* is_active

---

### Face Embeddings

Stores student face embeddings.

Fields:

* id
* student_id
* embedding_vector
* created_at

Embedding can be stored as JSON or float array.

---

### Attendance Sessions

A session created when a class is taking place.

Fields:

* id
* section_id
* device_id
* session_date
* start_time
* end_time

---

### Attendance Records

Fields:

* id
* student_id
* session_id
* checkin_time
* status (early, on_time, late, absent)
* confidence
* created_at

---

# API Requirements

Implement REST APIs grouped by module.

---

# Authentication APIs

POST /auth/login
POST /auth/register
GET /auth/me

Use JWT authentication.

---

# Academic APIs (Simulated University System)

These APIs simulate a university academic system.

GET /sections
GET /sections/{section_id}
GET /sections/{section_id}/students
GET /students/{student_id}/schedule
GET /schedule/today?room=A301

Admin APIs:

POST /admin/subjects
POST /admin/sections
POST /admin/enrollments
POST /admin/schedule

---

# Device APIs

POST /devices/register
GET /devices/{room}/schedule/today

Tablet uses these APIs to know when to start attendance.

---

# Face Registration APIs

POST /face/register

Input:

* student_id
* embedding_vector

GET /face/student/{student_id}

---

# Attendance APIs

POST /attendance/session/start
POST /attendance/checkin
POST /attendance/sync

GET /attendance/student/{student_id}
GET /attendance/section/{section_id}

---

# Attendance Logic

When tablet detects a face:

1. Tablet sends student_id + confidence score.
2. Backend checks:

   * session exists
   * student enrolled in section
3. Determine status:

Example rule:

* before class start → early
* 0–15 minutes after start → on_time
* 15–30 minutes → late
* beyond → absent

Save result in attendance_records.

---

# Notifications

Prepare endpoints for mobile app notifications:

GET /notifications/student/{id}
POST /notifications/send

---

# Teacher Statistics

Teacher dashboard API:

GET /teacher/{teacher_id}/section/{section_id}/statistics

Return:

* early students
* late students
* absent students

---

# Project Structure

Create a clean architecture:

backend/
app/
main.py
core/
config.py
security.py
db/
base.py
session.py
models/
schemas/
repositories/
services/
routers/
utils/
migrations/
requirements.txt

---

# Additional Requirements

Implement:

* database migrations with Alembic
* environment variables (.env)
* Swagger documentation
* sample seed data

Seed database with:

* 1 teacher
* 20 students
* 1 subject
* 1 course section
* 1 schedule

---

# Output Requirements

Generate:

1. Full FastAPI project structure
2. SQLAlchemy models
3. Pydantic schemas
4. API routers
5. Attendance logic
6. Example seed script

The code must be production-ready and modular.

Also:
- Add unit tests for auth and device flows
- Add rate limiting for /auth/login
- Add logging for security events
