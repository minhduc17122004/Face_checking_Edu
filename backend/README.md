# Hướng Dẫn Khởi Động Backend (Vedura API)

Dự án backend này được xây dựng bằng **FastAPI** và sử dụng **PostgreSQL**. Có hai cách chính để chạy dự án: sử dụng Docker (Khuyên Dùng) hoặc chạy qua Virtual Environment (Môi trường ảo của Python).

## 1. Sử dụng Docker (Khuyên Dùng)

Phương pháp này sẽ tự động khởi tạo database và cài đặt môi trường chạy API. Tính năng Hot-reload sẽ giúp tự động cập nhật code lên API mỗi khi bạn lưu thay đổi.

**Yêu cầu:** Đã cài đặt Docker Desktop.

- **Khởi động server & database (Chạy ngầm):**
  ```bash
  docker compose up -d
  ```

- **Xem log của ứng dụng:**
  Bạn có thể dừng lại luồng để theo dõi log chi tiết:
  ```bash
  docker logs -f backend-api-1
  ```

- **Khởi động lại (Restart):**
  ```bash
  docker compose restart
  ```

- **Tắt toàn bộ hệ thống:**
  ```bash
  docker compose down
  ```

- **Cập nhật Database (Database Migrations):**
  Khi có thay đổi cấu trúc bảng (thêm/sửa/xóa cột) trong file models, bạn cần chạy 2 lệnh sau để cập nhật PostgreSQL Database:
  ```bash
  # 1. Tự động mổ xẻ thay đổi và tạo file migration
  docker compose exec api alembic revision --autogenerate -m "Mô tả thay đổi"
  
  # 2. Thực thi file migration vào Database
  docker compose exec api alembic upgrade head
  ```

---

## 2. Chạy thủ công (Virtual Environment)

Sử dụng cách này nếu bạn muốn chạy file bằng `python` trên Windows trực tiếp. (Lưu ý: Bạn vẫn cần thiết lập và chạy database PostgreSQL trước). 

1. **Khởi động Database qua Docker (nhưng tắt container API):**
   Chạy lệnh này khởi động hệ thống và tắt riêng API container để nhường lại cổng 8000:
   ```bash
   docker compose up -d
   docker stop backend-api-1
   ```

2. **Cài đặt thư viện Python (Nếu chưa có):**
   Bật Virtual Environment và cập nhật môi trường:
   ```bash
   # Nếu bạn chưa cài đặt .venv từ trước
   python -m venv .venv
   
   # Cài đặt file requirments
   .venv\Scripts\pip install -r requirements.txt
   ```

3. **Khởi chạy ứng dụng:**
   Dùng `uvicorn` thông qua môi trường `venv`:
   ```bash
   .venv\Scripts\python -m uvicorn app.main:app --reload
   ```

## 3. Khắc phục lỗi kết nối tại Flutter
Hiện tượng ứng dụng Flutter không kết nối được tới Backend thường xuất phát từ việc thiết bị thay đổi địa chỉ mạng Wi-Fi (IP). 
Trong trường hợp này:
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
