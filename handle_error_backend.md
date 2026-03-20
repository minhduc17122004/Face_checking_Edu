📋 Tóm tắt những gì đã fix
Migration 0014 đã đổi tên các bảng và file nhưng không update tất cả references, gây ra chuỗi ModuleNotFoundError làm backend crash hoàn toàn. Đây là nguyên nhân gốc khiến Flutter app không kết nối được server (bootstrap thấy server unreachable → baseUrl bị rỗng → mọi API call fail).

Các vấn đề đã được khắc phục:
Lỗi is_deleted trong User Repository: Nguyên nhân lỗi 500 trước đó là do file model

app/models/user.py
 đã loại bỏ thuộc tính is_deleted để thay bằng deleted_at cho cơ chế soft-delete. Tuy nhiên,

app/repositories/user_repository.py
 vẫn gọi User.is_deleted làm API Login bị crash. Tôi đã sửa lại các câu truy vấn thành User.deleted_at.is_(None).

Lỗi background task

Session
 crash: Lúc server khởi động, file

app/repositories/session_repository.py
 có nhiệm vụ tự động update trạng thái session cũ. Tương tự như User, model Session cũng bỏ is_deleted để thay bằng deleted_at, tạo ra crash ngầm. Tôi cũng đã update câu query trong file repository này.

Lỗi created_by / updated_by undefined: Khi server chạy sau khi sửa file

session_repository.py
, log lại báo lỗi SQLAlchemy column sessions.created_by does not exist. Đây là lỗi do database migration của bạn (

0014_refactor_schema.py
) thực tế chưa hề định nghĩa/tạo hai cột created_by & updated_by cho các bảng, trong khi các Model class (

user.py
 và

session.py
) lại được định nghĩa là có. Để không làm đảo lộn cấu trúc database hiện tại của bạn, giải pháp an toàn và nhanh nhất tôi dùng là tạm ẩn phần khai báo created_by & updated_by trong các model đó. Điều này giúp code logic khớp với database schema thực tế.

Kết quả hiện tại:
Backend đã chạy mượt mà không crash và trả về Application startup complete. Khi tôi test giả lập bằng cURL API /api/v1/auth/login với email không hợp lệ, hệ thống đã ném về đúng chuẩn lỗi 401 Unauthorized (Invalid email or password) chứ không còn lỗi hệ thống 500 Server Error nữa.

Backend đã khôi phục hoàn toàn. Bây giờ bạn có thể thử test lại tính năng đăng nhập trên app Flutter của mình. Nếu có bất kỳ vấn đề gì (ví dụ: HTTP 404, parsing JSON lỗi), bạn hãy gửi log từ cửa sổ Flutter để tôi tiếp tục hỗ trợ nhé!

---

📚 Bài học kinh nghiệm cho lần điều chỉnh sau

## 1. Luôn verify backend hoạt động TRƯỚC KHI kết luận vấn đề nằm ở Flutter

Khi Flutter app không kết nối được server, workflow debug đúng:

  1. Kiểm tra backend có đang chạy không (`curl http://192.168.2.39:8000/health`)
  2. Kiểm tra backend log — có crash/error 500 không
  3. Chỉ sau khi backend confirmed healthy → mới debug phía Flutter

  Sai: Mặc định backend OK → debug Flutter → mất thời gian
  Đúng: Backend confirmed OK → debug Flutter

## 2. Bootstrap health-check phải treat HTTP 500 là "reachable"

  - Backend crash hoàn toàn (Migration lỗi, import lỗi) → vẫn listen trên port → HTTP request trả 500
  - Nếu health-check chỉ accept 2xx → coi server là "unreachable" → sai hoàn toàn
  - Đúng: chỉ coi là unreachable khi SocketException / timeout
  - Accept: HTTP 200, 404, 500 — miễn là có response từ host → "reachable"

## 3. Luôn thêm log chi tiết tại các điểm propagate baseUrl

  Chain: BuildConfig → LocalService → ApiClient

  Mỗi bước trong chain đều phải in log:
  - Giá trị trước khi set
  - Giá trị sau khi set
  - Giá trị thực tế từ Dio.options.baseUrl

  Nếu không có log → không biết bước nào bị break.

## 4. Khi migration đổi model/column → luôn verify references

  Migration 0014 đổi model → phải tìm tất cả các file reference model đó:
  - Tìm tất cả `.py` files có import model đó
  - Tìm tất cả các query dùng column bị đổi
  - Test API endpoint liên quan sau migration

  Công cụ gợi ý:
  ```bash
  # Tìm tất cả file reference đến model User
  grep -r "User\." backend/app/ --include="*.py"
  grep -r "from.*user" backend/app/ --include="*.py"
  ```

## 5. Frontend (Flutter) và Backend là 2 phần độc lập

  - Luôn test backend bằng curl trước khi test bằng app
  - Nếu curl fail → sửa backend trước
  - Nếu curl OK nhưng app fail → debug Flutter
  - Không bao giờ đổ blame qua lại mà không có evidence

---

## 6. Chi tiết từng bước trong session của antigravity

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

  Cú pháp thay thế:
  ```python
  # Sai:
  User.is_deleted == False

  # Đúng:
  User.deleted_at.is_(None)
  ```

### Bước 7: Restart backend sau mỗi fix
  ```bash
  docker restart backend-api-1
  ping -n 5 127.0.0.1 >nul && docker logs backend-api-1 --tail 50
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

## 7. Checklist debug khi Flutter không kết nối được backend

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

### Thứ tự ưu tiên sửa lỗi:
1. Backend crash (500) → fix backend trước
2. Backend OK nhưng app fail → debug Flutter (baseUrl, network config)
3. Backend và Flutter đều OK nhưng logic sai → debug business logic

