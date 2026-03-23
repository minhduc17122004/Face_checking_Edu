---
name: debug-backend-frontend
description: Debug workflow khi Flutter app không kết nối được backend. Sử dụng khi app không kết nối server, bootstrap baseUrl bị empty, backend crash, hoặc lỗi model/repository không sync.
---

# Debug Backend-Frontend Connectivity

## Nguyên tắc vàng

**Luôn verify backend bằng curl TRƯỚC KHI kết luận vấn đề nằm ở Flutter.**

```
Sai: Mặc định backend OK → debug Flutter → mất thời gian
Đúng: Backend confirmed OK → debug Flutter
```

## Debug Checklist (thứ tự ưu tiên)

### Cấp độ 1: Flutter Bootstrap
- [ ] Candidates có giá trị đúng không?
- [ ] `Selected BaseUrl` có bị empty không?
- [ ] `_verifyDioBaseUrl` in ra giá trị gì?

### Cấp độ 2: Backend connectivity
```bash
curl http://<IP>:8000/health
```
- [ ] Có response không?
- [ ] Backend trả HTTP 200/401/404? (500 = backend crash)

### Cấp độ 3: Backend API
```bash
curl -X POST http://<IP>:8000/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com","password":"test123"}'
```
- [ ] Check log: có lỗi AttributeError, SQLAlchemy error không?

### Cấp độ 4: Model/Repository
```bash
grep -r "is_deleted" backend/app/
grep -r "created_by\|updated_by" backend/app/models/
```
- [ ] Model và DB schema có khớp không?
- [ ] Migration đã tạo đủ columns chưa?

## Symptom thường gặp

### 1. baseUrl bị empty sau bootstrap

**Triệu chứng:**
```
Bootstrap: Candidates: [http://192.168.2.39:8000]
Bootstrap: Selected BaseUrl:           ← empty!
```

**Root cause có thể:**
- Backend crash hoàn toàn → HTTP 500 → health-check sai → coi là unreachable
- `LocalService` không parse/save được baseUrl
- `ApiClient` không set được Dio options

**Fix Bootstrap health-check:**
```dart
// ❌ Sai: chỉ accept 2xx
if (response.statusCode == 200) { ... }

// ✅ Đúng: accept mọi response có body
if (response.statusCode != null) { ... }
// Backend crash vẫn trả 500 → vẫn "reachable"
```

**Thứ tự trace:**
1. Log giá trị trước/sau khi set trong chain: `BuildConfig → LocalService → ApiClient`
2. Mỗi bước đều phải in log

### 2. Backend crash - ModuleNotFoundError / AttributeError

**Triệu chứng:**
```
AttributeError: type object 'User' has no attribute 'is_deleted'
```

**Root cause:** Migration đổi model nhưng repository chưa update.

**Ví dụ thực tế:**
- Migration 0014: `User.is_deleted` → `User.deleted_at`
- Repository vẫn dùng `User.is_deleted == False` → crash

**Cú pháp thay thế:**
```python
# Sai:
User.is_deleted == False

# Đúng:
User.deleted_at.is_(None)
```

### 3. Lỗi cascade - fix file A phát hiện lỗi ở file B

**Sequence thực tế:**
1. Fix `user_repository.py` (lỗi 500 khi login)
2. Restart backend
3. Thấy lỗi mới: `column sessions.created_by does not exist`
4. Tiếp tục fix model files

**Luôn restart backend sau mỗi fix:**
```bash
docker restart backend-api-1
ping -n 5 127.0.0.1 >nul && docker logs backend-api-1 --tail 50
```

### 4. 500 Internal Server Error khi load danh sách lớp học

**Triệu chứng:**
- API `/api/v1/student-groups` trả về HTTP 500
- Backend log có thể hiển thị lỗi lazy loading

**Root cause:** Khi lấy danh sách lớp học, Backend cố gắng truy cập thông tin của Giáo viên chủ nhiệm (`advisor`) và Khoa (`department`) để lấy tên hiển thị. Trong môi trường async, lazy loading không hoạt động.

**Fix:**
Sử dụng `selectinload` để eager load các relationships:

```python
# Trong student_group_repository.py
from sqlalchemy.orm import selectinload

query = (
    select(StudentGroup)
    .options(
        selectinload(StudentGroup.advisor),
        selectinload(StudentGroup.department)
    )
    .where(...)
)
```

**Tại sao cần selectinload:**
- Lazy loading không tương thích với async session
- `selectinload` tạo thêm 2 queries cho tất cả records (tốt hơn N+1)
- Đảm bảo dữ liệu luôn sẵn sàng khi truy xuất

**Verify sau fix:**
```bash
curl http://localhost:8000/api/v1/student-groups
# → HTTP 200 với danh sách đầy đủ
```

## Thứ tự ưu tiên sửa lỗi

1. **Backend crash (500)** → fix backend trước
2. **Backend OK nhưng app fail** → debug Flutter (baseUrl, network config)
3. **Backend và Flutter đều OK nhưng logic sai** → debug business logic

## Chi tiết kỹ thuật

### Khi migration đổi model/column

Sau khi migration chạy, phải tìm tất cả references:
```bash
# Tìm tất cả file reference đến model
grep -r "User\." backend/app/ --include="*.py"
grep -r "from.*user" backend/app/ --include="*.py"

# Tìm tất cả query dùng column bị đổi
grep -r "is_deleted" backend/app/repositories/ --include="*.py"
```

### Verify backend hoạt động

```bash
# Health check
curl http://192.168.2.39:8000/health

# Test login endpoint (phải trả 401, không phải 500)
curl -X POST http://localhost:8000/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"admin@example.com","password":"admin123"}'
# → HTTP 401 Unauthorized (đúng!)
# → KHÔNG phải HTTP 500 Server Error
```

## Additional Resources

- Chi tiết từng bước trong session debug, xem [reference.md](reference.md)
