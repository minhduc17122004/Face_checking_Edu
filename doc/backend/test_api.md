# Hướng Dẫn Test API Backend

> **Ngày cập nhật:** 2026-03-21
> **Framework:** FastAPI
> **Base URL:** http://localhost:8000

---

## 1. Authentication

### 1.1 Register (Tạo tài khoản mới)

```bash
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "full_name": "Nguyễn Văn Test",
    "role": "student"
  }'
```

**Response (201):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 900,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "test@example.com",
    "full_name": "Nguyễn Văn Test",
    "role": "student",
    "avatar_url": null,
    "created_at": "2026-03-21T10:00:00Z",
    "student_code": null,
    "class_name": null
  }
}
```

### 1.2 Login (Đăng nhập)

```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

**Response (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 900,
  "user": { ... }
}
```

**Response (401 - Sai mật khẩu):**
```json
{
  "detail": "Invalid email or password."
}
```

### 1.3 Refresh Token

```bash
curl -X POST http://localhost:8000/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

### 1.4 Get Current User

```bash
curl -X GET http://localhost:8000/api/v1/auth/me \
  -H "Authorization: Bearer <access_token>"
```

### 1.5 Logout

```bash
curl -X POST http://localhost:8000/api/v1/auth/logout \
  -H "Authorization: Bearer <access_token>"
```

---

## 2. Attendance

### 2.1 Create Attendance (Điểm danh)

```bash
curl -X POST http://localhost:8000/api/v1/attendance/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "student_id": 1,
    "checkin_time": "2026-03-21T08:15:00Z",
    "confidence": 0.95,
    "device_id": "550e8400-e29b-41d4-a716-446655440001"
  }'
```

**Response (201):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440002",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "student_id": 1,
  "checkin_time": "2026-03-21T08:15:00Z",
  "sync_time": "2026-03-21T08:15:05Z",
  "status": "present",
  "confidence": 0.95,
  "device_id": "550e8400-e29b-41d4-a716-446655440001",
  "created_at": "2026-03-21T08:15:05Z",
  "deleted_at": null
}
```

### 2.2 Get Attendance by Session

```bash
curl -X GET "http://localhost:8000/api/v1/attendance/session/550e8400-e29b-41d4-a716-446655440000?skip=0&limit=100" \
  -H "Authorization: Bearer <access_token>"
```

### 2.3 Get Attendance by Student

```bash
curl -X GET "http://localhost:8000/api/v1/attendance/student/1?skip=0&limit=100" \
  -H "Authorization: Bearer <access_token>"
```

### 2.4 Get Attendance Summary

```bash
curl -X GET http://localhost:8000/api/v1/attendance/summary/session/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer <access_token>"
```

**Response:**
```json
{
  "present": 45,
  "late": 5,
  "absent": 2,
  "total": 52,
  "attendance_rate": 0.9615
}
```

### 2.5 Delete Attendance

```bash
curl -X DELETE http://localhost:8000/api/v1/attendance/550e8400-e29b-41d4-a716-446655440002 \
  -H "Authorization: Bearer <access_token>"
```

---

## 3. Courses

### 3.1 Create Course

```bash
curl -X POST http://localhost:8000/api/v1/courses/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "course_name": "Toán Cao Cấp",
    "subject": "Mathematics",
    "course_code": "MATH101"
  }'
```

### 3.2 List Courses

```bash
curl -X GET "http://localhost:8000/api/v1/courses/?skip=0&limit=50" \
  -H "Authorization: Bearer <access_token>"
```

### 3.3 Get Course with Students

```bash
curl -X GET http://localhost:8000/api/v1/courses/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer <access_token>"
```

---

## 4. Sessions

### 4.1 Create Session

```bash
curl -X POST http://localhost:8000/api/v1/sessions/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "course_id": "550e8400-e29b-41d4-a716-446655440000",
    "session_date": "2026-03-21",
    "start_time": "2026-03-21T08:00:00Z",
    "end_time": "2026-03-21T10:00:00Z",
    "checkin_window_start": "2026-03-21T08:00:00Z",
    "checkin_window_end": "2026-03-21T10:00:00Z",
    "status": "scheduled"
  }'
```

### 4.2 List Sessions

```bash
curl -X GET "http://localhost:8000/api/v1/sessions/?skip=0&limit=50" \
  -H "Authorization: Bearer <access_token>"
```

### 4.3 Update Session Status

```bash
curl -X PATCH http://localhost:8000/api/v1/sessions/550e8400-e29b-41d4-a716-446655440000/status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "status": "active"
  }'
```

---

## 5. Students

### 5.1 Create Student

```bash
curl -X POST http://localhost:8000/api/v1/students/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "student_code": "B1800001"
  }'
```

### 5.2 List Students

```bash
curl -X GET "http://localhost:8000/api/v1/students/?skip=0&limit=100" \
  -H "Authorization: Bearer <access_token>"
```

---

## 6. Student Groups

### 6.1 Create Student Group

```bash
curl -X POST http://localhost:8000/api/v1/student-groups/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "code": "48K22",
    "name": "Khoa CNTT - K22",
    "faculty": "Khoa Công Nghệ Thông Tin",
    "course_year": "K22"
  }'
```

### 6.2 List Student Groups

```bash
curl -X GET "http://localhost:8000/api/v1/student-groups/?skip=0&limit=50" \
  -H "Authorization: Bearer <access_token>"
```

---

## 7. Course Enrollments

### 7.1 Enroll Student to Course

```bash
curl -X POST http://localhost:8000/api/v1/course-enrollments/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "course_id": "550e8400-e29b-41d4-a716-446655440000",
    "student_id": 1
  }'
```

### 7.2 List Enrollments

```bash
curl -X GET "http://localhost:8000/api/v1/course-enrollments/?skip=0&limit=100" \
  -H "Authorization: Bearer <access_token>"
```

---

## 8. Devices

### 8.1 Register Device

```bash
curl -X POST http://localhost:8000/api/v1/devices/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "device_code": "TAB-001",
    "device_name": "Máy tính bảng 1",
    "room": "P.101",
    "device_type": "tablet",
    "course_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

### 8.2 Device Sync (Pull data for offline)

```bash
curl -X GET http://localhost:8000/api/v1/devices/550e8400-e29b-41d4-a716-446655440000/sync \
  -H "Authorization: Bearer <access_token>"
```

**Response:**
```json
{
  "students": [
    {
      "id": 1,
      "student_code": "B1800001",
      "user_id": "550e8400-e29b-41d4-a716-446655440000"
    }
  ],
  "embeddings": [
    {
      "student_id": 1,
      "embedding": [0.123, -0.456, ...]
    }
  ],
  "sessions": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "session_date": "2026-03-21",
      "start_time": "2026-03-21T08:00:00Z",
      "status": "active"
    }
  ],
  "last_sync_at": "2026-03-21T08:00:00Z"
}
```

### 8.3 Bulk Attendance (Push from offline device)

```bash
curl -X POST http://localhost:8000/api/v1/devices/bulk-attendance \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "device_id": "550e8400-e29b-41d4-a716-446655440000",
    "records": [
      {
        "session_id": "550e8400-e29b-41d4-a716-446655440000",
        "student_id": 1,
        "checkin_time": "2026-03-21T08:15:00Z",
        "status": "present",
        "confidence": 0.95
      },
      {
        "session_id": "550e8400-e29b-41d4-a716-446655440000",
        "student_id": 2,
        "checkin_time": "2026-03-21T08:20:00Z",
        "status": "present",
        "confidence": 0.92
      }
    ]
  }'
```

**Response:**
```json
{
  "synced": 2,
  "errors": 0,
  "results": [
    {"student_id": 1, "status": "success", "attendance_id": "..."},
    {"student_id": 2, "status": "success", "attendance_id": "..."}
  ]
}
```

---

## 9. Faces

### 9.1 Register Face Embedding

```bash
curl -X POST http://localhost:8000/api/v1/students/1/face/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "embedding": [0.123, -0.456, 0.789, ...],
    "quality_score": 0.85
  }'
```

### 9.2 Get Face Status

```bash
curl -X GET http://localhost:8000/api/v1/students/1/face/face-status \
  -H "Authorization: Bearer <access_token>"
```

**Response:**
```json
{
  "has_face": true,
  "embedding_count": 3,
  "max_embeddings": 5
}
```

### 9.3 Export Face Embeddings for Course

```bash
curl -X GET http://localhost:8000/api/v1/students/1/face/courses/550e8400-e29b-41d4-a716-446655440000/face-embeddings \
  -H "Authorization: Bearer <access_token>"
```

---

## 10. Time Slots

### 10.1 Create Time Slot

```bash
curl -X POST http://localhost:8000/api/v1/time-slots/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "period_number": 1,
    "start_time": "07:30:00",
    "end_time": "08:15:00"
  }'
```

### 10.2 List Time Slots

```bash
curl -X GET http://localhost:8000/api/v1/time-slots/ \
  -H "Authorization: Bearer <access_token>"
```

---

## 11. Schedules

### 11.1 Create Schedule

```bash
curl -X POST http://localhost:8000/api/v1/schedules/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "course_id": "550e8400-e29b-41d4-a716-446655440000",
    "day_of_week": 2,
    "time_slot_id": 1,
    "room": "P.101"
  }'
```

### 11.2 List Schedules

```bash
curl -X GET "http://localhost:8000/api/v1/schedules/?skip=0&limit=50" \
  -H "Authorization: Bearer <access_token>"
```

---

## 12. Legacy API (Flutter)

### 12.1 Get All Employees

```bash
curl -X GET http://localhost:8000/api/employee/get_all_employees \
  -H "Authorization: Bearer <access_token>"
```

### 12.2 Create Employee

```bash
curl -X POST http://localhost:8000/api/employee/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "email": "student@example.com",
    "password": "password123",
    "full_name": "Nguyễn Văn A",
    "role": "student",
    "student_code": "B1800001"
  }'
```

### 12.3 Batch Create Employees

```bash
curl -X POST http://localhost:8000/api/employee/create/batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "employees": [
      {
        "email": "student1@example.com",
        "password": "password123",
        "full_name": "Nguyễn Văn A",
        "role": "student",
        "student_code": "B1800001"
      },
      {
        "email": "student2@example.com",
        "password": "password123",
        "full_name": "Trần Thị B",
        "role": "student",
        "student_code": "B1800002"
      }
    ]
  }'
```

### 12.4 Export Face Embeddings

```bash
curl -X GET http://localhost:8000/api/employee/export/json \
  -H "Authorization: Bearer <access_token>"
```

### 12.5 Import Face Embeddings

```bash
curl -X PUT http://localhost:8000/api/employee/update/embedding \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "student_id": 1,
    "embeddings": [[0.123, -0.456, ...], [0.789, -0.012, ...]]
  }'
```

### 12.6 Bulk Sync Attendance (Offline)

```bash
curl -X POST http://localhost:8000/api/attendance/history/sync_bulk_io \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "records": [
      {
        "student_id": 1,
        "class_id": 1,
        "checkin_time": "2026-03-21T08:15:00Z",
        "status": "present"
      }
    ]
  }'
```

---

## 13. Error Responses

### 401 Unauthorized

```json
{
  "detail": "Invalid email or password."
}
```

### 403 Forbidden

```json
{
  "detail": "Not authorized to access this resource."
}
```

### 404 Not Found

```json
{
  "detail": "Resource not found."
}
```

### 409 Conflict (Duplicate)

```json
{
  "detail": "A record with this value already exists."
}
```

### 422 Validation Error

```json
{
  "message": "Request validation failed",
  "detail": [
    {
      "loc": ["body", "email"],
      "msg": "value is not a valid email address",
      "type": "value_error.email"
    }
  ]
}
```

### 500 Internal Server Error

```json
{
  "message": "Internal server error",
  "detail": "An unexpected error occurred."
}
```

---

## 14. HTTP Status Codes

| Code | Mô tả |
|------|--------|
| 200 | OK - Request thành công |
| 201 | Created - Resource mới được tạo |
| 204 | No Content - Xóa thành công |
| 400 | Bad Request - Request không hợp lệ |
| 401 | Unauthorized - Chưa xác thực |
| 403 | Forbidden - Không có quyền truy cập |
| 404 | Not Found - Resource không tìm thấy |
| 409 | Conflict - Conflict dữ liệu |
| 422 | Unprocessable Entity - Validation lỗi |
| 500 | Internal Server Error - Lỗi server |

---

## 15. Authentication Flow

```
1. POST /api/v1/auth/register → Tạo tài khoản → Nhận tokens
2. POST /api/v1/auth/login → Đăng nhập → Nhận tokens
3. Copy access_token từ response
4. Thêm header: Authorization: Bearer <access_token>
5. Sử dụng access_token cho các request tiếp theo
6. Khi access_token hết hạn (15 phút): POST /api/v1/auth/refresh
```

---

## 16. Công Cụ Test

### cURL

```bash
# Lưu token vào biến
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Sử dụng token
curl -X GET http://localhost:8000/api/v1/auth/me \
  -H "Authorization: Bearer $TOKEN"
```

### HTTPie

```bash
# Login
http POST http://localhost:8000/api/v1/auth/login \
  email="test@example.com" password="password123"

# Get user
http GET http://localhost:8000/api/v1/auth/me \
  Authorization:"Bearer $TOKEN"
```

### Postman

1. Tạo Collection mới
2. Thêm request Login, lưu token vào Environment variable
3. Sử dụng Pre-request script để tự động thêm token:
```javascript
pm.request.headers.add({
    key: 'Authorization',
    value: 'Bearer ' + pm.environment.get('access_token')
});
```
