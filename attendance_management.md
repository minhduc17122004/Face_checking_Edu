# PROMPT: Triển khai chức năng Device-based Attendance Management

## Context

Tôi đang xây dựng hệ thống điểm danh (Face Attendance System) với:

* Backend: FastAPI + PostgreSQL + SQLAlchemy (async)
* Auth: JWT
* Role: admin / teacher / student
* App: Flutter (Clean Architecture + Bloc)

Hiện tại chưa có chức năng quản lý điểm danh theo thiết bị (tablet/admin mode).
Cần triển khai đầy đủ từ backend → API → flow cho mobile.

---

## Yêu cầu chức năng

### 1. Device Permission Management (trong Setting)

* Mỗi thiết bị muốn truy cập chức năng điểm danh phải được cấp quyền
* Nếu chưa có quyền:
  → Gửi request đến admin

#### Trạng thái:

* PENDING
* APPROVED
* REJECTED

#### Yêu cầu:

* Chỉ role ADMIN được:

  * Xem danh sách request
  * Approve / Reject
  * Gán thiết bị vào phòng (room_id) hoặc global

---

### 2. Database Design

Thiết kế các bảng:

#### devices

* id
* name
* api_key
* room_id (nullable)
* is_global (boolean)
* status (active/inactive)

#### device_requests

* id
* device_id
* status (PENDING / APPROVED / REJECTED)
* approved_by
* approved_at

#### attendance_sessions

* id
* course_session_id
* room_id
* start_time
* end_time

#### attendance_configs

* id
* course_session_id
* early_allowance (minutes)
* late_allowance (minutes)

#### attendance_records

* id
* student_id
* session_id
* checkin_time
* status (early, on_time, late, absent)
* minutes_diff

Constraint:

* UNIQUE(student_id, session_id)

---

### 3. API Design

#### Device

POST /devices/register
→ tạo device + status = pending

GET /devices/me
→ lấy thông tin device + permission

---

#### Admin

GET /device-requests
POST /device-requests/{id}/approve
POST /device-requests/{id}/reject

---

#### Room & Session

GET /rooms
→ danh sách phòng (theo quyền device)

GET /rooms/{room_id}/sessions
→ list session, sắp xếp:

1. session đang diễn ra
2. session sắp tới

---

#### Attendance

POST /attendance/check-in
→ check-in student

GET /attendance/session/{id}/summary
→ số lượng đã điểm danh / tổng

GET /attendance/history
→ filter theo role:

* admin: all
* teacher: course của mình
* student: bản thân

---

### 4. Business Logic

#### 4.1. Time Window

Cho phép check-in nếu:

NOW ∈ [start_time - early_allowance, end_time + late_allowance]

Nếu không:
→ throw error: "Chưa thể điểm danh cho học phần này"

---

#### 4.2. Status Calculation

delta = checkin_time - start_time

* delta < 0 → early
* delta = 0 → on_time
* delta > 0 → late

minutes_diff = abs(delta in minutes)

---

#### 4.3. Session Sorting

ORDER BY:
CASE
WHEN start_time <= NOW() AND end_time >= NOW() THEN 0
ELSE 1
END,
start_time ASC

---

#### 4.4. Device Authorization

* Nếu device.is_global = false:
  → chỉ được access room_id của nó
* Nếu true:
  → access mọi phòng

---

### 5. Mobile App Flow (Flutter)

#### Setting Screen

Nếu chưa có quyền:

* Hiển thị: "Yêu cầu cấp quyền"
* Button: "Gửi yêu cầu"

Nếu đã có quyền:

* Hiển thị danh sách phòng

---

#### Room → Session List

* List session theo thời gian
* Mỗi item:

  * Tên học phần
  * Thời gian
  * Trạng thái (có thể điểm danh / chưa)

---

#### Khi click session

IF trong time window:
→ Navigate: RouterName.checking

ELSE:
→ Show: "Chưa thể điểm danh cho học phần này"

---

#### Checking Screen

Hiển thị:

* Tên học phần
* Số lượng đã điểm danh / tổng
* Danh sách sinh viên đã điểm danh

Action:

* Scan face / manual check-in

---

#### History Tab

* Admin → full data
* Teacher → course của mình
* Student → cá nhân

---

### 6. Non-functional Requirements

* Sử dụng transaction khi check-in
* Tránh double check-in
* Có thể mở rộng WebSocket realtime
* Có logging/audit

---

### 7. Output yêu cầu từ AI

Hãy triển khai:

1. SQLAlchemy models
2. Alembic migration
3. FastAPI routers (clean structure)
4. Service layer (business logic)
5. Dependency auth (role + device)
6. Sample response JSON
7. Error handling chuẩn

---

## Mục tiêu

* Code sạch (Clean Architecture)
* Dễ scale
* Production-ready
