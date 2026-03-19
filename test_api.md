# Backend Implementation Plan - Face Recognition Attendance System

## 📌 Overview

Tài liệu này mô tả kế hoạch triển khai backend cho hệ thống điểm danh bằng nhận diện khuôn mặt.

**Tech stack đề xuất:**

* FastAPI (async)
* PostgreSQL
* SQLAlchemy ORM
* JWT Authentication

---

## 🎯 Mục tiêu triển khai

Triển khai backend theo từng bước:

1. Test toàn bộ API hiện có
2. Ổn định hệ thống và push code
3. Xây dựng authentication
4. Triển khai các feature quản lý (Teacher, Student, Class)
5. Mapping Student - Class
6. (Deferred) Face Recognition backend

---

## 🧪 1. Test toàn bộ API

### Mục tiêu

Đảm bảo tất cả API hoạt động ổn định trước khi phát triển tiếp.

### Thực hiện

* Test bằng Postman / Swagger
* Kiểm tra:

  * Status code
  * Response format (status, message, data)
  * Validate input
  * Không có lỗi 500

### Output

* Danh sách API đã test
* API pass / fail
* Danh sách bug cần fix

---

## 🚀 2. Push code lên Git

### Yêu cầu

* Clean code
* Xóa log/debug không cần thiết
* Không hardcode secret

### Commit message

```
feat: complete API testing and stabilization
```

---

## 🔐 3. Authentication System

### Mô hình

* Central auth qua bảng `users`

### Role hỗ trợ

* student
* teacher
* admin

### API cần có

* Register
* Login
* Refresh token
* Get current user

### Yêu cầu kỹ thuật

* Password hash: bcrypt
* JWT:

  * Access token (short-lived)
  * Refresh token (long-lived)

---

## 👨‍🏫 4. Quản lý Teacher

### Logic

* Tạo user
* Tạo teacher profile (1-1 với user)

### API

* Create teacher
* Get teacher list
* Get teacher detail

---

## 🎓 5. Quản lý Student

### Đặc điểm

* Có thể có hoặc không có account

### API

* Create student
* Get student list
* Update student

---

## 🏫 6. Quản lý Class

### API

* Create class
* Get class list
* Get class detail

---

## 🔗 7. Thêm học sinh vào lớp

### Thiết kế bảng

```
class_students
- id
- class_id (FK)
- student_id (FK)
```

### API

* Add student vào class
* Remove student khỏi class
* Get danh sách student trong class

---

## 🧠 8. Face Recognition (Triển khai sau)

### Trạng thái hiện tại

* Đã triển khai ở local (Flutter + ObjectBox)
* Chưa triển khai backend

### Kế hoạch sau

* API upload embedding
* API verify face
* Sync dữ liệu từ device lên server

### Ghi chú

* Sử dụng embedding vector (FaceNet 128-dim)
* Lưu vào bảng `face_embeddings`

---

## 📌 Nguyên tắc triển khai

* Clean Architecture:

  * Controller → Service → Repository
* Async toàn bộ hệ thống
* Validate bằng Pydantic
* Error handling rõ ràng

---

## 📦 Output mong muốn

Sau khi hoàn thành:

### Backend có:

* Authentication hoàn chỉnh
* CRUD Teacher, Student, Class
* Add Student vào Class

### Code:

* Clean
* Có commit rõ ràng

### API:

* Test đầy đủ
* Không lỗi 500

---

## 🚀 System Flow

```
User (Auth)
   ↓
Teacher tạo Class
   ↓
Add Student vào Class
   ↓
Device nhận diện face (local)
   ↓
Sync Attendance + Embedding lên server
```

---

## 📌 Ghi chú quan trọng

* Hệ thống follow mô hình **offline-first**
* AI inference chạy trên device
* Backend đóng vai trò:

  * Lưu trữ dữ liệu
  * Đồng bộ
  * Quản lý người dùng và lớp học

---

## 🔮 Định hướng phát triển

Trong tương lai có thể mở rộng:

* Real-time face verification từ backend
* Anti-spoofing server-side
* Dashboard quản lý điểm danh
* Phân tích dữ liệu (AI analytics)
