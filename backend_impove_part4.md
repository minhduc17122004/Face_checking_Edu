🎯 Mục tiêu

Refactor và mở rộng backend FastAPI hiện tại để:
	•	Đảm bảo data integrity (DB-level)
	•	Hoàn thiện business flow thực tế
	•	Triển khai đầy đủ:
	•	Classroom enrollment
	•	Face registration
	•	Device sync
	•	Attendance production flow

⸻

🧠 CONTEXT

Backend hiện tại:
	•	FastAPI + SQLAlchemy async
	•	PostgreSQL + Alembic
	•	Clean Architecture (Router → Service → Repository)
	•	Đã có:
	•	Attendance (session-based)
	•	AntiCheatService
	•	RBAC
	•	Refresh Token
	•	Soft delete
	•	API v1

Nhưng còn thiếu:
	•	DB constraints
	•	Ownership validation
	•	Face registration flow hoàn chỉnh
	•	Classroom + device sync APIs
	•	Transaction safety

⸻

⚠️ YÊU CẦU QUAN TRỌNG
	•	KHÔNG phá vỡ kiến trúc hiện tại
	•	Giữ pattern:
	•	Repository
	•	Service
	•	Router v1
	•	Code phải async hoàn toàn
	•	Tất cả logic quan trọng phải nằm trong Service (không đặt ở Router)

⸻

🔴 PHASE 1 — DATA INTEGRITY (BẮT BUỘC)

1.1 Thêm UNIQUE constraint chống duplicate attendance

Tạo Alembic migration mới:

ALTER TABLE attendance
ADD CONSTRAINT uq_attendance_session_student
UNIQUE (session_id, student_id);


⸻

1.2 Thêm các index quan trọng

CREATE INDEX ix_attendance_student_id ON attendance(student_id);
CREATE INDEX ix_attendance_created_at ON attendance(created_at);

CREATE INDEX ix_face_embeddings_active_student
ON face_embeddings(student_id)
WHERE is_active = true;


⸻

1.3 Đảm bảo mọi create/update dùng transaction

Trong tất cả Service:

async with self.db.begin():
    ...

Áp dụng cho:
	•	AttendanceService
	•	FaceService
	•	ClassroomStudentService

⸻

🟡 PHASE 2 — AUTHORIZATION (RẤT QUAN TRỌNG)

2.1 Implement ownership validation

Trong các service:

Classroom
	•	Teacher chỉ thao tác trên lớp của mình

Session
	•	Chỉ teacher sở hữu lớp mới tạo session

Attendance
	•	Không cho user ngoài lớp truy cập

⸻

2.2 Tạo helper function

def validate_classroom_owner(classroom, user_id):
    if classroom.teacher_id != user_id:
        raise HTTPException(403, "Not allowed")


⸻

🟢 PHASE 3 — CLASSROOM FLOW (CORE BUSINESS)

3.1 API: Lấy danh sách sinh viên trong lớp

GET /api/v1/classrooms/{classroom_id}/students

Response:
	•	danh sách student
	•	kèm:
	•	has_face (boolean)

⸻

3.2 Service logic
	•	Join:
	•	classroom_students
	•	students
	•	face_embeddings

⸻

3.3 Validate khi enroll
	•	Không cho enroll trùng
	•	Check student tồn tại
	•	Check classroom tồn tại

⸻

🔵 PHASE 4 — FACE REGISTRATION FLOW (QUAN TRỌNG NHẤT)

4.1 API: Đăng ký khuôn mặt

POST /api/v1/students/{student_id}/face

Request:

{
  "embedding": [float x128],
  "device_id": "uuid"
}


⸻

4.2 Service logic (FaceService)

Implement:

validate:
	•	student tồn tại
	•	device hợp lệ

business rules:
	•	max 5 embeddings / student
	•	nếu vượt:
	•	xóa embedding cũ (FIFO)

lưu:
	•	embedding_data
	•	is_active = true

⸻

4.3 API: Kiểm tra trạng thái face

GET /api/v1/students/{id}/face-status

Response:

{
  "has_face": true,
  "total_embeddings": 3
}


⸻

4.4 API: Export embeddings theo lớp (CHO DEVICE)

GET /api/v1/classrooms/{id}/face-embeddings

Response:
	•	danh sách:
	•	student_id
	•	embedding_data[]

⸻

🟣 PHASE 5 — DEVICE SYNC FLOW

5.1 API: Device pull data

GET /api/v1/devices/{device_id}/sync

Trả về:

{
  "students": [],
  "embeddings": [],
  "sessions": []
}


⸻

5.2 API: Bulk attendance từ device

POST /api/v1/attendance/bulk

	•	nhận list attendance
	•	validate từng record
	•	insert batch

⸻

🟠 PHASE 6 — SESSION LIFECYCLE

6.1 Auto update session status

Implement:

if now >= start_time → active
if now >= end_time → closed


⸻

6.2 Enforce trong AttendanceService
	•	Chỉ cho checkin khi session == active

⸻

🟤 PHASE 7 — LOGGING & AUDIT

7.1 Log các sự kiện
	•	login
	•	attendance
	•	duplicate attempt
	•	device activity

⸻

7.2 Tạo logger service

logger.info("attendance_created", extra={...})


⸻

⚫ PHASE 8 — PAGINATION & FILTER

Áp dụng cho:
	•	students
	•	attendance
	•	sessions

Support:
	•	page
	•	size
	•	filters:
	•	date
	•	status
	•	classroom

⸻

✅ OUTPUT YÊU CẦU

Sau khi implement, hệ thống phải:

✔ Hoạt động đầy đủ flow:
	1.	Teacher tạo lớp
	2.	Add student vào lớp
	3.	Student đăng ký face
	4.	Device sync data
	5.	Checkin bằng face
	6.	Attendance được lưu chính xác

⸻

🔥 EXPECTED RESULT

Backend đạt:
	•	Data consistency (DB-level)
	•	Không duplicate attendance
	•	Full flow: classroom → face → attendance
	•	Sẵn sàng tích hợp Flutter + AI model

⸻

🚀 BONUS (nếu còn thời gian)
	•	WebSocket real-time attendance
	•	Face quality scoring
	•	Embedding versioning

⸻

👉 GỢI Ý CHIẾN LƯỢC

Ưu tiên implement theo thứ tự:
	1.	Phase 1 (DB constraint) 🔴
	2.	Phase 4 (Face flow) 🔵
	3.	Phase 3 (Classroom) 🟢
	4.	Phase 5 (Device sync) 🟣
