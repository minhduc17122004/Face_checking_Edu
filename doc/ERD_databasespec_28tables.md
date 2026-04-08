# ĐẶC TẢ CƠ SỞ DỮ LIỆU
# Hệ thống Điểm danh Khuôn mặt - Face Attendance System
# Database Schema Specification
# Ngày: 28/03/2026
#
# Tổng số bảng: 15
# Nhóm 1: Xác thực & Người dùng   →  4 bảng
# Nhóm 2: Học thuật               →  6 bảng
# Nhóm 3: Phiên & Điểm danh       →  4 bảng
# Nhóm 4: Khuôn mặt & Thiết bị    →  4 bảng
#
# Ghi chú các cột:
#   Tên cột     – Tên trường trong bảng
#   Kiểu dữ liệu – Loại dữ liệu PostgreSQL
#   Khóa        – PK = Khóa chính, FK = Khóa ngoại, UK = Unique
#   Khác        – NOT NULL, AUTO INCREMENT, DEFAULT, CHECK constraint...
#   Mô tả      – Ý nghĩa nghiệp vụ của trường

---

## BẢNG 1: USERS
> Bảng trung tâm — lưu tài khoản cho tất cả người dùng (admin / teacher / student).
> Tên, avatar được lưu tại đây — **single source of truth**.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính định danh người dùng |
| email | VARCHAR(255) | **UK** | NOT NULL | Email đăng nhập, duy nhất không trùng |
| password_hash | VARCHAR(255) | — | NOT NULL | Mật khẩu đã băm (bcrypt/argon2) |
| full_name | VARCHAR(255) | — | NOT NULL | Họ và tên đầy đủ |
| role | VARCHAR(20) | — | NOT NULL, DEFAULT 'student', CHECK(role IN ('admin','teacher','student')) | Vai trò người dùng trong hệ thống |
| avatar_url | VARCHAR(500) | — | NULLABLE | URL ảnh đại diện |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo tài khoản |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm (NULL = đang hoạt động) |

---

## BẢNG 2: TEACHERS
> Hồ sơ giáo viên — quan hệ 1:1 nghiêm ngặt với User (role='teacher').
> Mã giáo viên, số điện thoại, và khoa được lưu tại đây.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | SERIAL / INT | **PK** | NOT NULL, AUTO INCREMENT | Khóa chính dạng số nguyên (tương thích Flutter) |
| user_id | UUID | **FK**, **UK** | NOT NULL, → users.id ON DELETE CASCADE | Liên kết 1:1 với bảng users |
| teacher_id | VARCHAR(50) | **UK** | NULLABLE | Mã giáo viên (mã số giảng viên), duy nhất |
| phone | VARCHAR(20) | — | NULLABLE | Số điện thoại liên hệ |
| department_id | UUID | **FK** | NULLABLE, → departments.id ON DELETE SET NULL | Khoa mà giáo viên thuộc về |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo hồ sơ |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |

---

## BẢNG 3: STUDENTS
> Hồ sơ sinh viên — quan hệ 1:1 nghiêm ngặt với User (role='student').
> Sử dụng **khóa chính INT** (không phải UUID) để tương thích Flutter.
> Mã sinh viên (MSSV), PIN offline, và lớp chủ quản được lưu tại đây.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | SERIAL / INT | **PK** | NOT NULL, AUTO INCREMENT | Khóa chính dạng số nguyên (tương thích Flutter) |
| user_id | UUID | **FK**, **UK** | NOT NULL, → users.id ON DELETE CASCADE | Liên kết 1:1 với bảng users |
| student_code | VARCHAR(50) | **UK** | NULLABLE | Mã sinh viên (MSSV), duy nhất không trùng |
| pin | VARCHAR(10) | — | NULLABLE | Mã PIN xác thực offline (mã hóa) |
| student_group_id | UUID | **FK** | NULLABLE, → student_groups.id ON DELETE SET NULL | Lớp chủ quản mà sinh viên thuộc về |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo hồ sơ |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |
| created_by | UUID | — | NULLABLE | Người tạo hồ sơ sinh viên |
| updated_by | UUID | — | NULLABLE | Người cập nhật hồ sơ sinh viên |

---

## BẢNG 4: REFRESH_TOKENS
> Lưu trữ JWT refresh token cho cơ chế đăng nhập.
> Hỗ trợ revoke token — khi đăng xuất hoặc admin thu hồi.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| user_id | UUID | **FK** | NOT NULL, → users.id ON DELETE CASCADE | Người dùng sở hữu token |
| token_jti | VARCHAR(64) | **UK** | NOT NULL | JWT Token ID (jti claim), dùng để revoke |
| device_id | VARCHAR(255) | — | NULLABLE | ID thiết bị đã đăng nhập (quản lý đa thiết bị) |
| device_info | JSONB | — | NULLABLE | Metadata thiết bị: browser, OS, IP... |
| expires_at | TIMESTAMPTZ | — | NOT NULL | Thời điểm token hết hạn |
| revoked | BOOLEAN | — | NOT NULL, DEFAULT FALSE | Cờ thu hồi (TRUE = đã bị thu hồi) |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo token |

---

## BẢNG 5: DEPARTMENTS
> Khoa / Bộ môn — đơn vị tổ chức học thuật.
> Giáo viên, sinh viên, và khóa học có thể gắn với một khoa.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| code | VARCHAR(50) | **UK** | NOT NULL | Mã khoa, duy nhất (ví dụ: "CNTT", "Toán") |
| name | VARCHAR(255) | — | NOT NULL | Tên đầy đủ của khoa |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo khoa |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |
| created_by | UUID | — | NULLABLE | Người tạo khoa |
| updated_by | UUID | — | NULLABLE | Người cập nhật khoa |

---

## BẢNG 6: STUDENT_GROUPS
> Lớp chủ quản — nhóm hành chính sinh viên (ví dụ: "48K21.1", "CNTT-K25").
> Khác với Course (lớp học phần), bảng này dùng cho mục đích hành chính.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| code | VARCHAR(50) | **UK** | NOT NULL | Mã lớp, duy nhất (ví dụ: "48K21.1") |
| name | VARCHAR(255) | — | NULLABLE | Tên lớp (tên thường gọi) |
| department_id | UUID | **FK** | NULLABLE, → departments.id ON DELETE SET NULL | Khoa quản lý lớp này |
| advisor_id | UUID | **FK** | NULLABLE, → users.id ON DELETE SET NULL | Giảng viên chủ nhiệm (GV cố vấn) |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo lớp |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |
| created_by | UUID | — | NULLABLE | Người tạo lớp |
| updated_by | UUID | — | NULLABLE | Người cập nhật lớp |

---

## BẢNG 7: COURSES
> Lớp học phần — đại diện cho một môn học cụ thể trong một học kỳ.
> Mỗi course được giảng dạy bởi một giáo viên và có nhiều sinh viên đăng ký.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| course_name | VARCHAR(255) | — | NOT NULL | Tên lớp học phần (ví dụ: "Nhập môn LT&TH") |
| course_code | VARCHAR(50) | **UK** | NULLABLE | Mã môn học (ví dụ: "CS101") |
| teacher_id | INT | **FK** | NULLABLE, → teachers.id ON DELETE SET NULL | Giáo viên giảng dạy lớp này |
| department_id | UUID | **FK** | NULLABLE, → departments.id ON DELETE SET NULL | Khoa sở hữu lớp học phần |
| room_id | UUID | **FK** | NULLABLE, → rooms.id ON DELETE SET NULL | Phòng học chính của lớp |
| attendance_mode | VARCHAR(20) | — | NOT NULL, DEFAULT 'preset', CHECK(attendance_mode IN ('preset','flexible')) | Chế độ điểm danh: preset (cố định) hoặc flexible (linh hoạt) |
| custom_window_start_minutes | INT | — | NOT NULL, DEFAULT 0 | Số phút cho phép checkin trước giờ bắt đầu (chế độ preset) |
| custom_window_end_minutes | INT | — | NOT NULL, DEFAULT 30 | Số phút cho phép checkin sau giờ bắt đầu (chế độ preset) |
| course_start_date | DATE | — | NULLABLE | Ngày bắt đầu hiệu lực của khóa học |
| course_end_date | DATE | — | NULLABLE | Ngày kết thúc hiệu lực của khóa học |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo lớp học phần |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |
| created_by | UUID | — | NULLABLE | Người tạo lớp |
| updated_by | UUID | — | NULLABLE | Người cập nhật lớp |

---

## BẢNG 8: COURSE_ENROLLMENTS
> Bảng trung gian (junction table) — quan hệ N:N giữa COURSES và STUDENTS.
> Mỗi bản ghi = một sinh viên đăng ký một lớp học phần.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| course_id | UUID | **FK** | NOT NULL, → courses.id ON DELETE CASCADE | Lớp học phần được đăng ký |
| student_id | INT | **FK** | NOT NULL, → students.id ON DELETE CASCADE | Sinh viên đăng ký |
| enrolled_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian sinh viên đăng ký lớp |

> **UNIQUE CONSTRAINT**: (course_id, student_id) — mỗi sinh viên chỉ đăng ký một lớp học phần một lần.
> **Bổ sung thống kê** (nếu cần): absent_count, leave_count, late_count, on_time_count kiểu INT DEFAULT 0.

---

## BẢNG 9: TIME_SLOTS
> Định nghĩa các tiết học trong ngày — mang tính toàn cục, dùng chung cho mọi khóa học.
> Ví dụ: Tiết 1 (07:00–08:00), Tiết 2 (08:00–09:00).

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | SERIAL / INT | **PK** | NOT NULL, AUTO INCREMENT | Khóa chính dạng số nguyên |
| period_number | INT | **UK** | NOT NULL | Số thứ tự tiết trong ngày (1, 2, 3...) |
| start_time | TIME | — | NOT NULL | Giờ bắt đầu tiết học |
| end_time | TIME | — | NOT NULL, CHECK(end_time > start_time) | Giờ kết thúc tiết học |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo tiết học |

---

## BẢNG 10: SCHEDULES
> Lịch học tuần — liên kết một COURSES với một ngày trong tuần và một TIME_SLOT.
> Ví dụ: Lớp CS101 học Thứ 2, Tiết 3.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| course_id | UUID | **FK** | NOT NULL, → courses.id ON DELETE CASCADE | Lớp học phần được xếp lịch |
| day_of_week | INT | — | NOT NULL, CHECK(day_of_week BETWEEN 1 AND 7) | Thứ trong tuần (1=Thứ 2, 7=Chủ nhật) |
| time_slot_id | INT | **FK** | NOT NULL, → time_slots.id ON DELETE RESTRICT | Tiết học trong ngày |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo lịch |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |
| created_by | UUID | — | NULLABLE | Người tạo lịch |
| updated_by | UUID | — | NULLABLE | Người cập nhật lịch |

> **UNIQUE CONSTRAINT**: (course_id, day_of_week, time_slot_id) — không xếp trùng tiết cho cùng một lớp.
> **Phòng học**: được lấy từ course.room_id (Phase 9), không lưu riêng trên SCHEDULES.

---

## BẢNG 11: SESSIONS
> Phiên điểm danh — một **instance** cụ thể của một COURSES vào một ngày cụ thể.
> Đại diện cho "buổi học thứ N" của một lớp. Có thể ở trạng thái: scheduled → active → closed.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| course_id | UUID | **FK** | NOT NULL, → courses.id ON DELETE CASCADE | Lớp học phần mà phiên này thuộc về |
| schedule_id | UUID | **FK** | NULLABLE, → schedules.id ON DELETE SET NULL | Lịch học gốc sinh ra phiên này |
| session_date | DATE | — | NOT NULL | Ngày diễn ra phiên điểm danh (chỉ ngày, không giờ) |
| start_time | TIMESTAMPTZ | — | NOT NULL | Thời điểm bắt đầu phiên (timestamp có múi giờ) |
| end_time | TIMESTAMPTZ | — | NULLABLE | Thời điểm kết thúc phiên |
| checkin_window_start | TIMESTAMPTZ | — | NULLABLE | Thời điểm bắt đầu cho phép điểm danh |
| checkin_window_end | TIMESTAMPTZ | — | NULLABLE | Thời điểm kết thúc cho phép điểm danh |
| status | VARCHAR(20) | — | NOT NULL, DEFAULT 'scheduled', CHECK(status IN ('scheduled','active','closed')) | Trạng thái phiên |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo phiên |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |

> **INDEX**: (course_id, start_time) để truy vấn phiên theo lớp và thời gian nhanh.

---

## BẢNG 12: ATTENDANCES
> Bản ghi điểm danh — mỗi bản ghi = một sinh viên checkin trong một phiên.
> Thiết kế **offline-first**: lưu cả giờ thiết bị và giờ server.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| session_id | UUID | **FK** | NOT NULL, → sessions.id ON DELETE CASCADE | Phiên điểm danh |
| student_id | INT | **FK** | NOT NULL, → students.id ON DELETE CASCADE | Sinh viên điểm danh |
| checkin_time | TIMESTAMPTZ | — | NOT NULL | Thời gian điểm danh theo đồng hồ thiết bị |
| sync_time | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian đồng bộ lên server |
| status | VARCHAR(20) | — | NOT NULL, DEFAULT 'present', CHECK(status IN ('present','late','absent','early','on_time')) | Trạng thái điểm danh |
| confidence | FLOAT | — | NULLABLE | Độ tin cậy nhận diện khuôn mặt (0.0–1.0) |
| device_id | UUID | **FK** | NULLABLE, → devices.id ON DELETE SET NULL | Thiết bị dùng để điểm danh |
| minutes_diff | INT | — | NULLABLE | Số phút chênh lệch so với giờ bắt đầu (dương = trễ, âm = sớm) |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo bản ghi |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |

> **UNIQUE CONSTRAINT**: (session_id, student_id) — mỗi sinh viên chỉ điểm danh một lần trong một phiên.
> **INDEX**: (session_id, student_id), (checkin_time), (status).

---

## BẢNG 13: ATTENDANCE_CONFIGS
> Cấu hình điểm danh riêng cho từng phiên — cho phép admin điều chỉnh thời gian trễ cho phép.
> Nếu phiên không có config → sử dụng giá trị mặc định (early_allowance=15, late_allowance=15).

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| session_id | UUID | **FK**, **UK** | NOT NULL, → sessions.id ON DELETE CASCADE | Phiên được cấu hình (mỗi phiên tối đa 1 config) |
| room_id | UUID | **FK** | NULLABLE, → rooms.id ON DELETE SET NULL | Phòng áp dụng cấu hình |
| mode | VARCHAR(20) | — | NULLABLE, DEFAULT NULL, CHECK(mode IN ('FIXED','FLEXIBLE')) | Chế độ: FIXED (cố định) hoặc FLEXIBLE (linh hoạt) |
| early_allowance | INT | — | NOT NULL, DEFAULT 15, CHECK(early_allowance >= 0 AND early_allowance <= 120) | Số phút sinh viên được phép điểm danh SỚM trước giờ bắt đầu |
| late_allowance | INT | — | NOT NULL, DEFAULT 15, CHECK(late_allowance >= 0 AND late_allowance <= 120) | Số phút sinh viên được phép điểm danh TRỄ sau giờ bắt đầu |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo cấu hình |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |

> **QUI CHƯỚNG TRÌNH**: early_allowance + late_allowance xác định khoảng thời gian cho phép điểm danh:
> `Valid checkin ∈ [start_time - early_allowance, start_time + late_allowance]`

---

## BẢNG 14: ATTENDANCE_AUDIT_LOGS
> Nhật ký kiểm toán cho mọi thao tác liên quan đến điểm danh.
> Ghi lại lịch sử: check-in, chỉnh sửa thủ công, xóa bản ghi.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| student_id | INT | — | NOT NULL, INDEX | ID sinh viên liên quan |
| session_id | UUID | — | NOT NULL, INDEX | ID phiên điểm danh |
| device_id | UUID | **FK** | NULLABLE, → devices.id ON DELETE SET NULL | Thiết bị thực hiện hành động |
| action | VARCHAR(20) | — | NOT NULL | Loại hành động: 'checkin', 'manual', 'delete' |
| old_status | VARCHAR(20) | — | NULLABLE | Trạng thái trước khi thay đổi |
| new_status | VARCHAR(20) | — | NULLABLE | Trạng thái sau khi thay đổi |
| minutes_diff | INT | — | NULLABLE | Số phút chênh lệch tại thời điểm check-in |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW(), INDEX | Thời gian thực hiện hành động |

> **INDEX**: (session_id, student_id), (session_id), (student_id), (created_at).

---

## BẢNG 15: FACE_EMBEDDINGS
> Lưu trữ vector đặc trưng khuôn mặt (128 chiều) cho từng sinh viên.
> Mỗi sinh viên có thể có nhiều embedding (góc chụp khác nhau, nhiều lần đăng ký).
> Chỉ embedding có `is_active = TRUE` mới được dùng để nhận diện.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| student_id | INT | **FK** | NOT NULL, → students.id ON DELETE CASCADE | Sinh viên sở hữu vector khuôn mặt |
| embedding | JSON | — | NOT NULL | Vector 128 chiều — danh sách số thực (định dạng JSON array) |
| is_active | BOOLEAN | — | NOT NULL, DEFAULT TRUE, INDEX | Cờ kích hoạt — chỉ embedding ACTIVE mới dùng để nhận diện |
| quality_score | FLOAT | — | NULLABLE | Điểm chất lượng ảnh khuôn mặt (0.0–1.0, ≥ 0.7 = chất lượng tốt) |
| device_id | UUID | **FK** | NULLABLE, → devices.id ON DELETE SET NULL | Thiết bị chụp khuôn mặt này |
| captured_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời điểm chụp khuôn mặt |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian lưu embedding |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |

> **INDEX**: (student_id).
> **pgvector-ready**: có thể chuyển `embedding` từ JSON sang `VECTOR(128)` nếu cần tìm kiếm similarity.

---

## BẢNG 16: ROOMS
> Phòng học / phòng máy — định danh vị trí vật lý của thiết bị và khóa học.
> Phase 9: Room trở thành trung tâm cho cơ chế **anti-cheat** (device.room_id = course.room_id).

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| code | VARCHAR(50) | **UK** | NOT NULL | Mã phòng, duy nhất (ví dụ: "A101", "PM02") |
| name | VARCHAR(255) | — | NOT NULL | Tên phòng học |
| building | VARCHAR(100) | — | NULLABLE | Tòa nhà chứa phòng |
| floor | INT | — | NULLABLE | Tầng của phòng |
| capacity | INT | — | NULLABLE | Sức chứa tối đa của phòng |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian tạo phòng |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |
| created_by | UUID | — | NULLABLE | Người tạo phòng |
| updated_by | UUID | — | NULLABLE | Người cập nhật phòng |

---

## BẢNG 17: DEVICES
> Thiết bị điểm danh (tablet, kiosk) — đăng ký với hệ thống.
> Phase 9 bổ sung `is_global` và `status` để quản lý quyền truy cập theo phòng.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| device_code | VARCHAR(50) | **UK** | NOT NULL | Mã thiết bị vật lý (serial), duy nhất |
| device_name | VARCHAR(100) | — | NULLABLE | Tên hiển thị của thiết bị |
| room_id | UUID | **FK** | NULLABLE, → rooms.id ON DELETE SET NULL | Phòng mà thiết bị được lắp đặt |
| device_type | VARCHAR(50) | — | NOT NULL, DEFAULT 'tablet' | Loại thiết bị: tablet, kiosk, desktop... |
| is_active | BOOLEAN | — | NOT NULL, DEFAULT TRUE | Cờ kích hoạt thiết bị |
| is_global | BOOLEAN | — | NOT NULL, DEFAULT FALSE | Nếu TRUE → thiết bị được dùng ở mọi phòng |
| status | VARCHAR(20) | — | NOT NULL, DEFAULT 'ACTIVE' | Trạng thái: ACTIVE (hoạt động) / INACTIVE (bị khóa bởi admin) |
| ip_address | VARCHAR(45) | — | NULLABLE | Địa chỉ IP hiện tại của thiết bị |
| mac_address | VARCHAR(17) | — | NULLABLE | Địa chỉ MAC của thiết bị |
| last_active_at | TIMESTAMPTZ | — | NULLABLE | Thời điểm thiết bị hoạt động lần cuối |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian đăng ký thiết bị |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |
| created_by | UUID | — | NULLABLE | Người đăng ký thiết bị |
| updated_by | UUID | — | NULLABLE | Người cập nhật thiết bị |

---

## BẢNG 18: DEVICE_REQUESTS
> Yêu cầu cấp quyền thiết bị — flow phê duyệt: PENDING → APPROVED / REJECTED.
> Giáo viên/xử lý viên gửi yêu cầu, Admin duyệt để cấp quyền điểm danh hàng loạt.

| Tên cột | Kiểu dữ liệu | Khóa | Khác | Mô tả |
|---------|-------------|------|------|--------|
| id | UUID | **PK** | NOT NULL, DEFAULT uuid_generate_v4() | Khóa chính |
| device_code | VARCHAR(50) | — | NOT NULL, INDEX | Mã thiết bị được yêu cầu |
| device_name | VARCHAR(100) | — | NULLABLE | Tên thiết bị được yêu cầu |
| room_id | UUID | **FK** | NULLABLE, → rooms.id ON DELETE SET NULL | Phòng cần cấp quyền (NULL = tất cả phòng) |
| requested_by | UUID | **FK** | NULLABLE, → users.id ON DELETE SET NULL | Người gửi yêu cầu cấp quyền |
| status | VARCHAR(20) | — | NOT NULL, DEFAULT 'PENDING', INDEX | Trạng thái: PENDING / APPROVED / REJECTED |
| reviewed_by | UUID | **FK** | NULLABLE, → users.id ON DELETE SET NULL | Admin duyệt yêu cầu |
| reviewed_at | TIMESTAMPTZ | — | NULLABLE | Thời điểm admin duyệt yêu cầu |
| admin_note | VARCHAR(255) | — | NULLABLE | Ghi chú của admin khi duyệt/từ chối |
| created_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian gửi yêu cầu |
| updated_at | TIMESTAMPTZ | — | NOT NULL, DEFAULT NOW() | Thời gian cập nhật gần nhất |
| deleted_at | TIMESTAMPTZ | — | NULLABLE, INDEX | Đánh dấu xóa mềm |

---

## TÓM TẮT SƠ ĐỒ QUAN HỆ

```
╔══════════════════════════════════════════════════════════════╗
║                    USERS (tâm hệ thống)                      ║
╚═══════╤════════════════╤════════════════╤═══════════════════╝
        │ 1:1            │ 1:1            │ 1:N
        ▼                ▼                ▼
   TEACHERS ───N:1──► DEPARTMENTS ◄──N:1── STUDENT_GROUPS ──N:1──► USERS (advisor)
        │                                           │
        │ 1:N                                       │ 1:N
        ▼                                           ▼
   COURSES ◄─────────────┐                    STUDENTS
        │                │                          │
        ├──N:1── ROOMS ◄─┘                          ├──N:1──► STUDENT_GROUPS
        │                                           │
        │ N:N                                       │ N:N
        ▼                                           ▼
   COURSE_ENROLLMENTS ◄──────────────────────► STUDENTS
        │
        ├──N:1── SCHEDULES
        │               │
        │               └──N:1── TIME_SLOTS
        │
        ├──N:1── SESSIONS
        │               │
        │               ├──1:1── ATTENDANCE_CONFIGS
        │               │
        │               └──1:N── ATTENDANCES
        │                             │
        │                             ├──N:1──► STUDENTS
        │                             ├──N:1──► DEVICES
        │                             │
        │                             └──1:N── ATTENDANCE_AUDIT_LOGS
        │
        ├──N:1── SCHEDULES ──N:1── SESSIONS ──1:N── ATTENDANCES
        │
        └──N:1── COURSES ──1:N── SCHEDULES

DEVICES ◄──N:1── ROOMS ──N:1── DEVICE_REQUESTS
   │
   ├──N:1── ATTENDANCES
   ├──N:1── FACE_EMBEDDINGS ◄──N:1── STUDENTS
   └──N:1── DEVICE_REQUESTS ◄───N:1── USERS (requester)
                          └──N:1── USERS (reviewer)
```

---

## BẢNG TÓM TẮT CÁC RÀNG BUỘC (CONSTRAINTS)

| STT | Tên ràng buộc | Bảng | Kiểu | Mô tả |
|-----|--------------|------|------|--------|
| 1 | ck_users_role | users | CHECK | role IN ('admin','teacher','student') |
| 2 | ck_session_status | sessions | CHECK | status IN ('scheduled','active','closed') |
| 3 | ck_attendance_status | attendances | CHECK | status IN ('present','late','absent','early','on_time') |
| 4 | ck_day_of_week | schedules | CHECK | day_of_week BETWEEN 1 AND 7 |
| 5 | ck_time_slot_order | time_slots | CHECK | start_time < end_time |
| 6 | uq_enrollment_course_student | course_enrollments | UNIQUE | (course_id, student_id) |
| 7 | uq_attendance_session_student | attendances | UNIQUE | (session_id, student_id) |
| 8 | uq_schedule_course_day_slot | schedules | UNIQUE | (course_id, day_of_week, time_slot_id) |
| 9 | ix_departments_code | departments | UNIQUE INDEX | (code) |
| 10 | ix_sessions_course_start | sessions | INDEX | (course_id, start_time) |
| 11 | ix_attendance_session_student | attendances | INDEX | (session_id, student_id) |
| 12 | ix_attendance_checkin_time | attendances | INDEX | (checkin_time) |
| 13 | ix_attendance_status | attendances | INDEX | (status) |
| 14 | ix_face_embeddings_student | face_embeddings | INDEX | (student_id) |
| 15 | ix_device_requests_status | device_requests | INDEX | (status) |

---

## BẢNG TÓM TẮT SỐ LƯỢNG TRƯỜNG

| Nhóm | Bảng | Số trường | Số FK | Số INDEX |
|------|------|----------|-------|----------|
| **Xác thực** | USERS | 10 | — | 2 |
| | TEACHERS | 8 | 2 | 2 |
| | STUDENTS | 10 | 3 | 2 |
| | REFRESH_TOKENS | 8 | 1 | 2 |
| **Học thuật** | DEPARTMENTS | 8 | — | 3 |
| | STUDENT_GROUPS | 10 | 2 | 2 |
| | COURSES | 16 | 4 | 2 |
| | COURSE_ENROLLMENTS | 4 | 2 | 2 |
| | TIME_SLOTS | 5 | — | 1 |
| | SCHEDULES | 8 | 2 | 2 |
| **Phiên & Điểm danh** | SESSIONS | 12 | 2 | 3 |
| | ATTENDANCES | 13 | 3 | 5 |
| | ATTENDANCE_CONFIGS | 8 | 2 | 1 |
| | ATTENDANCE_AUDIT_LOGS | 9 | 1 | 4 |
| **Khuôn mặt & Thiết bị** | FACE_EMBEDDINGS | 11 | 2 | 2 |
| | ROOMS | 10 | — | 2 |
| | DEVICES | 16 | 1 | 2 |
| | DEVICE_REQUESTS | 12 | 3 | 3 |
| | | **TỔNG: 18 bảng** | **31 FK** | **47 INDEX** |
