# Hướng Dẫn Xử Lý Lỗi Backend

> **Ngày cập nhật:** 2026-03-21
> **Framework:** FastAPI + SQLAlchemy 2.x (async)

---

## Tóm tắt những gì đã fix

Migration 0014 đã đổi tên các bảng và file nhưng không update tất cả references, gây ra chuỗi `ModuleNotFoundError` làm backend crash hoàn toàn. Đây là nguyên nhân gốc khiến Flutter app không kết nối được server (bootstrap thấy server unreachable → baseUrl bị rỗng → mọi API call fail).

Các vấn đề đã được khắc phục:

### Lỗi `deleted_at` trong User Repository

Nguyên nhân lỗi 500 trước đó là do file model `app/models/user.py` đã loại bỏ thuộc tính `is_deleted` để thay bằng `deleted_at` cho cơ chế soft-delete. Tuy nhiên, `app/repositories/user_repository.py` vẫn gọi `User.is_deleted` làm API Login bị crash.

```python
# Sai:
User.is_deleted == False

# Đúng:
User.deleted_at.is_(None)
```

### Lỗi Background Task Session

Session crash: Lúc server khởi động, file `app/repositories/session_repository.py` có nhiệm vụ tự động update trạng thái session cũ. Tương tự như User, model Session cũng bỏ `is_deleted` để thay bằng `deleted_at`, tạo ra crash ngầm.

### Lỗi `created_by` / `updated_by` undefined

Khi server chạy sau khi sửa file `session_repository.py`, log báo lỗi `column sessions.created_by does not exist`. Đây là lỗi do database migration chưa tạo hai cột `created_by` & `updated_by` cho các bảng, trong khi các Model class lại được định nghĩa là có. Giải pháp đã dùng là tạm ẩn phần khai báo `created_by` & `updated_by` trong các model đó.

### Kết quả hiện tại

Backend đã chạy mượt mà không crash và trả về `Application startup complete`. Khi test bằng cURL API `/api/v1/auth/login` với email không hợp lệ, hệ thống đã ném về đúng chuẩn lỗi `401 Unauthorized` (Invalid email or password) chứ không còn lỗi hệ thống `500 Server Error` nữa.

---

## Bài Học Kinh Nghiệm

### 1. Luôn verify backend hoạt động TRƯỚC KHI kết luận vấn đề nằm ở Flutter

Khi Flutter app không kết nối được server, workflow debug đúng:

1. Kiểm tra backend có đang chạy không (`curl http://192.168.2.39:8000/health`)
2. Kiểm tra backend log — có crash/error 500 không
3. Chỉ sau khi backend confirmed healthy → mới debug phía Flutter

**Sai:** Mặc định backend OK → debug Flutter → mất thời gian
**Đúng:** Backend confirmed OK → debug Flutter

### 2. Bootstrap health-check phải treat HTTP 500 là "reachable"

- Backend crash hoàn toàn (Migration lỗi, import lỗi) → vẫn listen trên port → HTTP request trả 500
- Nếu health-check chỉ accept 2xx → coi server là "unreachable" → sai hoàn toàn
- **Đúng:** chỉ coi là unreachable khi SocketException / timeout
- **Accept:** HTTP 200, 404, 500 — miễn là có response từ host → "reachable"

### 3. Luôn thêm log chi tiết tại các điểm propagate baseUrl

Chain: BuildConfig → LocalService → ApiClient

Mỗi bước trong chain đều phải in log:
- Giá trị trước khi set
- Giá trị sau khi set
- Giá trị thực tế từ Dio.options.baseUrl

Nếu không có log → không biết bước nào bị break.

### 4. Khi migration đổi model/column → luôn verify references

Migration đổi model → phải tìm tất cả các file reference model đó:
- Tìm tất cả `.py` files có import model đó
- Tìm tất cả các query dùng column bị đổi
- Test API endpoint liên quan sau migration

```bash
# Tìm tất cả file reference đến model User
grep -r "User\." backend/app/ --include="*.py"
grep -r "from.*user" backend/app/ --include="*.py"

# Tìm tất cả references đến cột cũ
grep -r "is_deleted" backend/app/repositories/ --include="*.py"
grep -r "classroom_id" backend/app/ --include="*.py"
grep -r "class_name" backend/app/ --include="*.py"
```

### 5. Frontend (Flutter) và Backend là 2 phần độc lập

- Luôn test backend bằng curl trước khi test bằng app
- Nếu curl fail → sửa backend trước
- Nếu curl OK nhưng app fail → debug Flutter
- Không bao giờ đổ blame qua lại mà không có evidence

---

## Chi Tiết Từng Bước Debug

### Bước 1: Xác định symptom chính xác từ Flutter log

```
Bootstrap: Candidates: [http://192.168.2.39:8000]
Bootstrap: Selected BaseUrl:           ← empty!
```

→ baseUrl bị empty sau bootstrap

### Bước 2: Verify backend trước (curl)

```bash
docker logs backend-api-1 --tail 50
```

→ Thấy backend crash với lỗi `AttributeError: type object 'User' has no attribute 'is_deleted'`

**QUAN TRỌNG:** Backend crash → Flutter không kết nối được → fix backend TRƯỚC

### Bước 3: Trace lỗi từ stack trace

```
AttributeError: type object 'User' has no attribute 'is_deleted'
ở app/repositories/user_repository.py, dòng 35
```

### Bước 4: Tìm root cause — Model vs Repository không sync

- Mở `app/models/user.py` → thấy `deleted_at` thay vì `is_deleted`
- Model đã đổi từ `is_deleted` → `deleted_at` nhưng Repository chưa update

### Bước 5: Tìm TẤT CẢ các file reference đến is_deleted

```bash
grep -r "is_deleted" backend/app/repositories/ --include="*.py"
```

→ Tìm được cả `user_repository.py` và `session_repository.py`

### Bước 6: Fix từng file theo đúng thứ tự phụ thuộc

1. `user_repository.py` — fix trước (lỗi 500 khi login)
2. `session_repository.py` — fix sau (crash lúc startup)

```python
# Sai:
User.is_deleted == False

# Đúng:
User.deleted_at.is_(None)
```

### Bước 7: Restart backend sau mỗi fix

```bash
docker restart backend-api-1
docker logs -f backend-api-1
```

### Bước 8: Fix lỗi cascade — khi fix file A phát hiện lỗi ở file B

- Sau khi fix `session_repository.py` → restart → thấy lỗi mới:
  ```
  column sessions.created_by does not exist
  ```
- Tiếp tục fix: comment `created_by` / `updated_by` trong model files

### Bước 9: Verify cuối cùng bằng curl

```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"admin@example.com","password":"admin123"}'
```

→ HTTP 401 Unauthorized (đúng!) thay vì HTTP 500 (lỗi hệ thống)

---

## Checklist Debug Khi Flutter Không Kết Nối Được Backend

### Cấp độ 1: Flutter Bootstrap

- [ ] `flutter run` → quan sát log bootstrap
- [ ] Candidates có giá trị đúng không?
- [ ] `Selected BaseUrl` có bị empty không?
- [ ] `_verifyDioBaseUrl` in ra giá trị gì?

### Cấp độ 2: Backend connectivity

- [ ] `curl http://<IP>:8000/health` → có response không?
- [ ] `docker logs backend-api-1 --tail 30` → backend có crash không?
- [ ] Backend có trả HTTP 200/401/404 không? (500 = backend crash)

### Cấp độ 3: Backend API (nếu curl được nhưng app fail)

- [ ] `curl -X POST http://<IP>:8000/api/v1/auth/login ...` → trả gì?
- [ ] Check log backend: có lỗi AttributeError, SQLAlchemy error không?

### Cấp độ 4: Model/Repository (nếu backend lỗi 500)

- [ ] `grep -r "is_deleted" backend/app/` → có file nào chưa update không?
- [ ] `grep -r "created_by\|updated_by" backend/app/models/` → model và DB schema có khớp không?
- [ ] Check migration files xem có missing columns không

### Thứ tự ưu tiên sửa lỗi

1. Backend crash (500) → fix backend trước
2. Backend OK nhưng app fail → debug Flutter (baseUrl, network config)
3. Backend và Flutter đều OK nhưng logic sai → debug business logic

---

## Các Lỗi Thường Gặp Sau Migration

### 1. `AttributeError: type object 'X' has no attribute 'is_deleted'`

**Nguyên nhân:** Model đã xóa `is_deleted`, chỉ còn `deleted_at`, nhưng repository vẫn dùng `is_deleted`.

**Fix:**
```python
# Thay đổi trong tất cả repository files:
# Từ:
.filter(Model.is_deleted == False)
# Sang:
.filter(Model.deleted_at.is_(None))
```

### 2. `column X.created_by does not exist`

**Nguyên nhân:** Model khai báo `created_by`/`updated_by` nhưng migration chưa tạo cột.

**Fix:**
```python
# Comment out trong model:
# created_by: Mapped[Optional[uuid.UUID]] = mapped_column(
#     UUID(as_uuid=True), nullable=True
# )
```

### 3. 500 Internal Server Error khi load danh sách lớp học (Student Groups)

**Nguyên nhân:** Khi lấy danh sách lớp học, Backend cố gắng truy cập thông tin của Giáo viên chủ nhiệm (`advisor`) và Khoa (`department`) để lấy tên hiển thị. Tuy nhiên, trong môi trường xử lý bất đồng bộ (Async), các mối quan hệ này không được tự động tải (lazy loading), dẫn đến lỗi khi code cố gắng truy xuất chúng.

**Triệu chứng:**
- API trả về HTTP 500 Internal Server Error
- Backend log có thể hiển thị lỗi lazy loading hoặc relationship không được tải

**Fix:**
Sử dụng `selectinload` trong SQLAlchemy để "nạp sẵn" dữ liệu quan hệ ngay trong một câu lệnh truy vấn duy nhất:

```python
# Trong backend/app/repositories/student_group_repository.py

# Thêm selectinload cho các relationship cần thiết
from sqlalchemy.orm import selectinload

# Khi query lấy danh sách student groups:
query = (
    select(StudentGroup)
    .options(
        selectinload(StudentGroup.advisor),      # Load teacher relationship
        selectinload(StudentGroup.department)    # Load department relationship
    )
    .where(...)
)
```

**Tại sao cần selectinload:**
- **Lazy loading không hoạt động trong async:** SQLAlchemy lazy loading không tương thích với async session
- **Eager loading:** `selectinload` tạo ra một câu query riêng để load tất cả related objects, đảm bảo dữ liệu luôn sẵn sàng
- **Hiệu suất:** Tốt hơn N+1 queries vì chỉ tạo thêm 2 queries cho tất cả records thay vì 1 query cho mỗi record

**Kiểm tra sau khi fix:**
```bash
curl http://localhost:8000/api/v1/student-groups
# → HTTP 200 với danh sách đầy đủ
```

### 3. Backend crash ngay khi startup

**Nguyên nhân:** Lỗi import do đổi tên bảng/cột sau migration.

**Cách kiểm tra:**
```bash
# Xem log
docker logs backend-api-1 --tail 100

# Thử import models
docker compose exec api python -c "from app.models import *; print('OK')"
```

### 4. API trả 500 nhưng không có crash

**Nguyên nhân:** Lỗi trong logic handler.

**Cách kiểm tra:**
```bash
# Bật DEBUG mode
# Trong .env:
DEBUG=True

# Restart
docker compose restart api

# Test lại
curl -v http://localhost:8000/api/v1/auth/me
```

### 5. Flutter baseUrl bị empty

**Nguyên nhân:** Backend trả HTTP 500 (thay vì 200) nên Flutter coi là unreachable.

**Fix:**
1. Sửa backend trước (xem các bước trên)
2. Restart backend
3. Test lại Flutter

---

## Commands Hữu Ích Cho Debug

```bash
# Xem logs
docker logs -f backend-api-1

# Test import
docker compose exec api python -c "from app.models import *; print('Models OK')"
docker compose exec api python -c "from app.repositories import *; print('Repos OK')"

# Test database connection
docker compose exec api python -c "from app.core.database import engine; print('DB OK')"

# Run migrations
docker compose exec api alembic upgrade head

# Check migration status
docker compose exec api alembic current
docker compose exec api alembic history

# Restart backend
docker compose restart api
```
