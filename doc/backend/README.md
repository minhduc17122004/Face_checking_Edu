# Hướng Dẫn Khởi Động Backend (Face Time Keeping - Vedura API)

Dự án backend này được xây dựng bằng **FastAPI** và sử dụng **PostgreSQL**. Có hai cách chính để chạy dự án: sử dụng Docker (Khuyên Dùng) hoặc chạy qua Virtual Environment (Môi trường ảo của Python).

## 1. Sử dụng Docker (Khuyên Dùng)

Phương pháp này sẽ tự động khởi tạo database và cài đặt môi trường chạy API. Tính năng Hot-reload sẽ giúp tự động cập nhật code lên API mỗi khi bạn lưu thay đổi.

**Yêu cầu:** Đã cài đặt Docker Desktop.

### Khởi động server & database (Chạy ngầm)

```bash
docker compose up -d
```

### Xem log của ứng dụng

Bạn có thể dừng lại luồng để theo dõi log chi tiết:

```bash
docker logs -f backend-api-1
```

### Khởi động lại (Restart)

```bash
docker compose restart
```

### Tắt toàn bộ hệ thống

```bash
docker compose down
```

### Cập nhật Database (Database Migrations)

Khi có thay đổi cấu trúc bảng (thêm/sửa/xóa cột) trong file models, bạn cần chạy 2 lệnh sau để cập nhật PostgreSQL Database:

```bash
# 1. Tự động mổ xẻ thay đổi và tạo file migration
docker compose exec api alembic revision --autogenerate -m "Mô tả thay đổi"

# 2. Thực thi file migration vào Database
docker compose exec api alembic upgrade head
```

### Kiểm tra trạng thái migrations

```bash
# Xem migration hiện tại
docker compose exec api alembic current

# Xem lịch sử migrations
docker compose exec api alembic history
```

---

## 2. Chạy thủ công (Virtual Environment)

Sử dụng cách này nếu bạn muốn chạy file bằng `python` trên Windows trực tiếp. (Lưu ý: Bạn vẫn cần thiết lập và chạy database PostgreSQL trước).

### Bước 1: Khởi động Database qua Docker (nhưng tắt riêng API)

Chạy lệnh này khởi động hệ thống và tắt riêng API container để nhường lại cổng 8000:

```bash
docker compose up -d
docker stop backend-api-1
```

### Bước 2: Cài đặt thư viện Python (Nếu chưa có)

Bật Virtual Environment và cập nhật môi trường:

```bash
# Nếu bạn chưa cài đặt .venv từ trước
python -m venv .venv

# Cài đặt file requirments
.venv\Scripts\pip install -r requirements.txt
```

### Bước 3: Khởi chạy ứng dụng

Dùng `uvicorn` thông qua môi trường `venv`:

```bash
.venv\Scripts\python -m uvicorn app.main:app --reload
```

---

## 3. Kiểm tra Backend

### Health Check

```bash
curl http://localhost:8000/health
```

Response:
```json
{"status":"ok","app":"Vedura Face Attendance API","version":"1.0.0"}
```

### Swagger Documentation

Mở trình duyệt: http://localhost:8000/docs

### API Endpoints

#### v1 API (Production-ready)

| Endpoint | Mô tả |
|----------|--------|
| `POST /api/v1/auth/register` | Đăng ký tài khoản mới |
| `POST /api/v1/auth/login` | Đăng nhập, nhận JWT tokens |
| `POST /api/v1/auth/refresh` | Refresh access token |
| `GET /api/v1/auth/me` | Lấy thông tin user hiện tại |
| `POST /api/v1/auth/avatar` | Upload avatar (512px JPEG) |
| `POST /api/v1/auth/logout` | Logout, thu hồi tokens |
| `POST /api/v1/attendance/` | Tạo bản ghi điểm danh |
| `GET /api/v1/attendance/session/{id}` | Lấy điểm danh theo phiên |
| `GET /api/v1/devices/{id}/sync` | Pull dữ liệu cho device offline |
| `POST /api/v1/devices/bulk-attendance` | Push bulk attendance từ offline |

#### Legacy API (Flutter - Migration pending)

| Endpoint | Mô tả |
|----------|--------|
| `POST /auth/login` | Đăng nhập |
| `GET /api/employee/get_all_employees` | Lấy danh sách nhân viên |
| `POST /api/employee/create/batch` | Tạo batch nhân viên |
| `POST /api/employee/avatars/upload` | Upload avatars |
| `GET /api/employee/export/json` | Export face embeddings |
| `PUT /api/employee/update/embedding` | Import embeddings |
| `POST /api/attendance/history/sync_bulk_io` | Bulk sync điểm danh offline |

---

## 4. Cấu Hình Môi Trường

### File `.env`

Tạo file `.env` trong thư mục `backend/` (nếu chưa có):

```env
# Database
DATABASE_URL=postgresql+asyncpg://vedura:vedura_pass@db:5432/vedura_db

# JWT - THAY ĐỔI TRONG PRODUCTION!
SECRET_KEY=changeme-super-secret-key-please-update-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# App
APP_NAME=Vedura Face Attendance API
DEBUG=False
CORS_ORIGINS=["*"]

# Uploads
UPLOAD_DIR=uploads
```

> ⚠️ **Quan trọng**: Thay đổi `SECRET_KEY` trong production để đảm bảo bảo mật JWT.

---

## 5. Khắc Phục Lỗi Kết Nối tại Flutter

Hiện tượng ứng dụng Flutter không kết nối được tới Backend thường xuất phát từ việc thiết bị thay đổi địa chỉ mạng Wi-Fi (IP). Trong trường hợp này:

1. Bạn hãy bật Terminal và gõ:
   ```bash
   ipconfig
   ```
2. Thu thập dòng `IPv4 Address`. Ví dụ `192.168.1.100`.
3. Đi tới tệp `[Dự án Flutter]\lib\configs\build_config.dart`.
4. Thay dòng `'http://192.168.2.39:8000'` thành IP mới:
   ```dart
   defaultValue: 'http://192.168.1.100:8000',
   ```
5. Đóng gói/Chạy lại ứng dụng Flutter.

---

## 6. Cấu Trúc Database (Sau Migration 0014)

Xem chi tiết tại [final_db.md](./final_db.md).

### Các Bảng Chính

| Bảng | Mô tả |
|------|--------|
| `users` | Bảng xác thực trung tâm |
| `teachers` | Hồ sơ giáo viên (1:1 với users) |
| `students` | Hồ sơ sinh viên (1:1 với users, INT PK) |
| `student_groups` | Lớp hành chính (lớp chủ quản) |
| `courses` | Lớp học phần |
| `course_enrollments` | Đăng ký sinh viên - lớp học phần |
| `sessions` | Phiên điểm danh |
| `attendance` | Bản ghi điểm danh |
| `face_embeddings` | Vector khuôn mặt 128 chiều |
| `devices` | Thiết bị điểm danh |
| `refresh_tokens` | Refresh token có thể thu hồi |

---

## 7. Tài Liệu Tham Khảo

| Tài liệu | Mô tả |
|-----------|--------|
| [final_db.md](./final_db.md) | Sơ đồ database chi tiết |
| [backend_analysis.md](./backend_analysis.md) | Phân tích kiến trúc hệ thống |
| [backend_implementation_summary.md](./backend_implementation_summary.md) | Tổng kết triển khai |
| [backend_implementation_report.md](./backend_implementation_report.md) | Báo cáo chi tiết từng phase |
| [database_refactor_report.md](./database_refactor_report.md) | Báo cáo tái cấu trúc Migration 0014 |
| [handle_error_backend.md](./handle_error_backend.md) | Hướng dẫn xử lý lỗi backend |
| [test_api.md](./test_api.md) | Hướng dẫn test API |

---

## 8. Lệnh Hữu Ích

```bash
# Xem logs backend
docker logs -f backend-api-1

# Restart backend
docker compose restart api

# Chạy migration
docker compose exec api alembic upgrade head

# Tạo migration mới
docker compose exec api alembic revision --autogenerate -m "Mô tả"

# Kiểm tra database
docker compose exec db psql -U vedura -d vedura_db -c "\dt"

# Shell vào container
docker compose exec api bash
```
