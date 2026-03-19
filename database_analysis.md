# Phân Tích Cấu Trúc Cơ Sở Dữ Liệu (Database Analysis) - Vedura AI Face Recognition Attendance System

Dự án hiện tại đang sử dụng **PostgreSQL** làm cơ sở dữ liệu chính, được quản lý thông qua **SQLAlchemy ORM** và **Alembic** để thiết kế và migrate cấu trúc. 

Dưới đây là phần phân tích chi tiết về các bảng và mối quan hệ (Entity-Relationship) đang được triển khai trong project `backend/app/models`:

---

## 1. Bảng `users` (Central Authentication)
Bảng trung tâm quản lý tài khoản và quyền truy cập của hệ thống. Tất cả các người dùng (Admin, Teacher, Student) đều có một tài khoản ở đây để phục vụ cho việc đăng nhập/xác thực.

- **Khóa chính (PK):** `id` (UUID)
- **Các trường quan trọng:**
  - `email`: Tên đăng nhập/email (Unique).
  - `password_hash`: Chuỗi mật khẩu đã được mã hóa.
  - `full_name`: Tên đầy đủ của người dùng.
  - `role`: Vai trò (`'teacher'`, `'student'`, `'admin'`).
  - `avatar_url`: Đường dẫn tới ảnh đại diện.
- **Mối quan hệ:**
  - `1 - 1` với bảng `teachers` (nếu role='teacher').
  - `1 - 1` với bảng `students` (nếu role='student').
  - `1 - N` với bảng `classes` (Giáo viên quản lý nhiều lớp học).

---

## 2. Bảng `teachers` (Teacher Profile)
Đóng vai trò là thông tin mở rộng (profile) của người dùng nếu họ là một giáo viên.

- **Khóa chính (PK):** `id` (Integer - tự động tăng)
- **Khóa ngoại (FK):** `user_id` (UUID - liên kết tới bảng `users`)
- **Các trường quan trọng:**
  - `employee_code`: Mã nhân viên / Mã giáo viên (Unique).
  - `phone`, `department` (Phòng ban), `avatar_url`.
- **Mối quan hệ:** Liên kết 1-1 chặt chẽ với bảng `users` qua `user_id` (cascade delete).

---

## 3. Bảng `students` (Student Profile)
Bảng lưu trữ thông tin sinh viên/học sinh. 
*Đặc biệt: Bảng này chủ ý dùng `id` dạng Integer (Thay vì UUID) để đảm bảo tính tương thích ngược (backward-compatibility) với base code ứng dụng Flutter cũ (phân tách từ kiểu `Employee` của hệ thống HRM).*

- **Khóa chính (PK):** `id` (Integer - tự động tăng)
- **Khóa ngoại (FK):** `user_id` (UUID - nullable, liên kết tới bảng `users`)
- **Các trường quan trọng:**
  - `name`: Tên sinh viên.
  - `pin`: Mã PIN để check-in.
  - `job_title`: Được tái sử dụng làm bí danh (alias) mã lớp học/nhóm do tính tương thích với Flutter API.
  - `avatar_url`, `has_avatar`, `attachment_id`, `is_synced` (Đánh dấu đồng bộ dữ liệu ảnh/avatar).
- **Mối quan hệ:**
  - `1 - 1` với bảng `users`.
  - `1 - N` với bảng `face_embeddings` (Một sinh viên có thể có nhiều khuôn mặt/dữ liệu embedding).
  - `1 - N` với bảng `attendance_records` (Một sinh viên có nhiều bản ghi điểm danh).

---

## 4. Bảng `face_embeddings` (Dữ liệu nhận diện khuôn mặt)
Chứa dữ liệu các vector đặc trưng (128-dimensional) từ model AI như FaceNet. Định dạng thân thiện với ứng dụng Flutter.

- **Khóa chính (PK):** `id` (UUID)
- **Khóa ngoại (FK):** `student_id` (Integer - liên kết tới `students`)
- **Các trường quan trọng:**
  - `embedding_data`: Lưu trữ dữ liệu dạng `JSONB` từ PostgreSQL. Dữ liệu này chứa danh sách các số thực (floats) biểu diễn vector của khuôn mặt. Hỗ trợ multi-pose (nhiều góc khuôn mặt) thông qua mảng 2 chiều.

---

## 5. Bảng `classes` (Classroom)
Quản lý các lớp học hoặc khoá học do các giáo viên (teacher) tạo ra.

- **Khóa chính (PK):** `id` (UUID)
- **Khóa ngoại (FK):** `teacher_id` (UUID - liên kết tới `users`)
- **Các trường quan trọng:**
  - `class_name`: Tên lớp học.
  - `subject`: Bộ môn.
- **Mối quan hệ:**
  - `1 - N` với bảng `attendance_records` (Mỗi lớp nắm giữ các bản ghi điểm danh tương ứng với lớp đó).

---

## 6. Bảng `attendance_records` (Bản ghi điểm danh)
Lưu trữ thông tin điểm danh mỗi lần sinh viên quét khuôn mặt. Bảng này hỗ trợ tốt mô hình Offline-first từ thiết bị di động.

- **Khóa chính (PK):** `id` (UUID)
- **Khóa ngoại (FK):** 
  - `student_id` (Integer - liên kết tới `students`).
  - `class_id` (UUID - nullable, liên kết tới `classes`).
- **Các trường quan trọng (Dual-timestamp design):**
  - `checkin_time`: Thời gian ngoại tuyến (Offline time) ở máy trạm lúc nhận diện.
  - `sync_time`: Thời gian thực tế Server nhận được từ máy trạm (Tránh sai lệch khi mất mạng).
- **Thuộc tính điểm danh & AI:**
  - `record_type`: `'checkin'` hoặc `'checkout'`.
  - `confidence`: Tỉ lệ chính xác % AI nhận diện và dự đoán độ mượt.
  - `device_id`: Mã thiết bị tiến hành điểm danh.
  - `status`: Trạng thái (`'present'`, `'absent'`, `'late'`).
  - `latitude`, `longitude`: Vị trí địa lý điểm danh (GPS).
  - `image_url`: Hình ảnh snapshot thu được trong khoảnh khắc nhận diện.

---

## 7. Bảng `devices` (Thiết bị độc lập)
Quản lý thông tin trạng thái các thiết bị (Smartphone/Tablet chạy Flutter) cắm ở các phòng học dùng để kiểm tra khuôn mặt.

- **Khóa chính (PK):** `id` (UUID)
- **Các trường quan trọng:**
  - `device_code`: Mã thiết bị (Unique).
  - `room`: Tên / Số phòng triển khai thiết bị.
  - `is_active`: Trạng thái thiết bị đang hoạt động hay không (boolean).

---

## Tổng kết sơ đồ quan hệ chính (ERD Concept)

```text
 [users] ──(1:1)──> [teachers]
   │
   ├──(1:1)──> [students] ──(1:N)──> [face_embeddings] (JSONB AI Vectors)
   │               │
   │               └──(1:N)────────┐
   │                               v
   └──(1:N)──> [classes]  ──(1:N)──> [attendance_records] <── (Dual-Time & GPS Setup)
                                      Ngữ cảnh: Lịch sử điểm danh chứa ảnh gốc, 
                                      vị trí và phần % độ chính xác AI nhận diện.

 [devices] (Biệt lập: Quản lý thiết bị điểm danh)
```

## Nhận xét Kiến trúc
1. **Thiết kế Backward-Compatible:** System đã có sự điều chỉnh thông minh trong bảng `Student` (PK kiểu `Integer` thay vì `UUID`) và các trường như `job_title` nhằm không làm gãy (break) base code và JSON parsers của Flutter App bên mobile cũ.
2. **Offline-First Resilience:** Bảng `attendance_records` sử dụng 2 timestamps (`checkin_time` & `sync_time`) giúp giải quyết hoàn hảo bài toán ghi nhận điểm danh chính xác tại nơi không có kết nối internet và đồng bộ lại sau đó.
3. **Hiệu năng Vector:** Bảng `face_embeddings` dùng `JSONB` của PostgreSQL để lưu vector là giải pháp chuẩn để parse dễ dàng sang JSON dạng list `[[...]]` phục vụ cho SQLite/Thiết bị dưới Client, vừa đáp ứng tốt việc truy xuất trên Backend.
