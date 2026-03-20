# Chi tiết kỹ thuật debug Backend-Frontend

## Chi tiết từng bước trong session debug

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

### Bước 7: Restart backend sau mỗi fix

```bash
docker restart backend-api-1
ping -n 5 127.0.0.1 >nul && docker logs backend-api-1 --tail 50
```

### Bước 8: Fix lỗi cascade

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

## Checklist debug đầy đủ

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

## Các lỗi đã gặp và cách fix

### 1. Lỗi is_deleted trong User Repository

**Nguyên nhân:** File model `app/models/user.py` đã loại bỏ `is_deleted` để thay bằng `deleted_at`, nhưng `app/repositories/user_repository.py` vẫn gọi `User.is_deleted`.

**Fix:**
```python
# Sai:
User.is_deleted == False

# Đúng:
User.deleted_at.is_(None)
```

### 2. Lỗi background task - Session crash

**Nguyên nhân:** Khi server khởi động, `app/repositories/session_repository.py` có nhiệm vụ tự động update trạng thái session cũ. Tương tự User, model Session cũng bỏ `is_deleted` để thay bằng `deleted_at`.

**Fix:** Update câu query trong `session_repository.py`.

### 3. Lỗi created_by / updated_by undefined

**Nguyên nhân:** Database migration chưa định nghĩa/tạo hai cột `created_by` & `updated_by` cho các bảng, trong khi các Model class lại được định nghĩa là có.

**Fix an toàn:** Tạm ẩn phần khai báo `created_by` & `updated_by` trong các model để code logic khớp với database schema thực tế.

## Bootstrap health-check - key insight

Backend crash hoàn toàn (Migration lỗi, import lỗi) → vẫn listen trên port → HTTP request trả 500.

```
Nếu health-check chỉ accept 2xx → coi server là "unreachable" → SAI
Đúng: chỉ coi là unreachable khi SocketException / timeout
Accept: HTTP 200, 404, 500 — miễn là có response từ host → "reachable"
```

## Luôn thêm log chi tiết tại các điểm propagate baseUrl

Chain: `BuildConfig → LocalService → ApiClient`

Mỗi bước trong chain đều phải in log:
- Giá trị trước khi set
- Giá trị sau khi set
- Giá trị thực tế từ Dio.options.baseUrl

Nếu không có log → không biết bước nào bị break.
