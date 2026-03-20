You are a senior backend architect.
Your task is to **refactor and redesign the database schema** for a Face Recognition Attendance System built with:

* FastAPI + SQLAlchemy + PostgreSQL
* AI Face Recognition (FaceNet embeddings)
* Mobile-first + Offline-first architecture

The current schema has issues:

* Redundant fields
* Inconsistent data ownership
* Weak relationships (especially 1-1)
* Mixing business data with technical fields

---

## 🚨 Problems to Fix

### 1. Data Redundancy

* `avatar_url` exists in multiple tables: `users`, `students`, `teachers`
* `students` contains unnecessary fields:

  * `has_avatar`
  * `attachment_id`
  * `is_synced`

👉 Requirement:

* Remove all redundant avatar-related fields
* Keep **ONLY `avatar_url` in `users`**
* Ensure avatar upload still works system-wide

---

### 2. Invalid / Weak Relationships

#### Current:

* `students.user_id` is nullable → weak 1-1

👉 Requirement:

* Convert to **strict 1-1 relationship**
* Enforce:

  * `students.user_id UNIQUE NOT NULL`
  * `teachers.user_id UNIQUE NOT NULL`

---

### 3. Mixing Business Logic with Technical Fields

Remove fields that belong to infrastructure, not database:

* `is_synced`
* `attachment_id`
* any derived fields (e.g., `has_avatar`)

👉 These should be handled by:

* background jobs / services / cache

---

### 4. Naming & Domain Confusion

Current:

* `academic_classes`
* `classes`

👉 Requirement:

* Rename for clarity:

  * `academic_classes` → `student_groups`
  * `classes` → `courses`

---

### 5. Improve Face Embedding Storage

Current:

* `embedding_data JSONB`

👉 Requirement:

* Use **pgvector** if possible:

```sql
embedding VECTOR(128)
```

* If not, keep JSONB but structure properly

---

### 6. Soft Delete Optimization

Current:

* `is_deleted` + `deleted_at` everywhere

👉 Requirement:

* Remove `is_deleted`
* Keep only:

```sql
deleted_at TIMESTAMPTZ NULL
```

---

### 7. Device Responsibility Separation

Current `devices` table is overloaded

👉 Requirement:

* Keep `devices` as hardware registry
* Ensure relationships are clean and minimal
* Do NOT overload business logic into devices

---

## ✅ Expected Output

### 1. Final Clean Database Schema

Provide:

* Full PostgreSQL schema (DDL)
* All tables with:

  * PK, FK
  * constraints
  * indexes
* Use best practices:

  * UUID for main entities
  * INT for high-frequency tables (optional)

---

### 2. ERD (Text-based)

Example:

```
users (1) ─── (1) students
users (1) ─── (1) teachers
students (1) ─── (N) face_embeddings
courses (1) ─── (N) sessions
sessions (1) ─── (N) attendance
```

---

### 3. Migration Plan

Provide step-by-step migration:

1. Backup data
2. Drop redundant columns
3. Migrate avatar data → users
4. Add constraints (UNIQUE, NOT NULL)
5. Rename tables
6. Update foreign keys

---

### 4. Design Justification (IMPORTANT)

Explain:

* Why removing redundancy improves consistency
* Why 1-1 relationship is enforced
* Why separating auth (`users`) from domain (`students`) is correct
* Why pgvector improves AI performance

---

### 5. Performance Considerations

Include:

* Index strategy
* Query optimization for:

  * attendance
  * face recognition
* Scalability (10k–100k users)

---

## ⚠️ Constraints

* DO NOT break existing business logic
* Ensure backward compatibility where possible
* Keep schema clean, minimal, and scalable
* Follow Clean Architecture principles

---

## 🎯 Final Goal

Produce a **production-ready, normalized, scalable database schema**
suitable for:

* AI-powered attendance system
* Mobile + offline-first usage
* Graduation thesis documentation

---

## 🧩 Bonus (if possible)

* Suggest improvements for:

  * multi-tenant support
  * audit logging
  * event-driven architecture

---
