# Hướng dẫn Thay đổi Schema và Migration (Alembic)

Tài liệu này hướng dẫn cách thay đổi cấu trúc Database (Schema) trong Backend và sử dụng **Alembic** để cập nhật (migrate) Database mà không làm mất dữ liệu.

## Quy trình chung (Workflow)

Khi bạn muốn thêm, sửa hoặc xóa một trường (field/column) trong Database, hãy làm theo 4 bước sau:

1.  **Chỉnh sửa Model**: Sửa file định nghĩa Model trong thư mục `backend/app/models/`.
2.  **Tạo file Migration**: Dùng lệnh `alembic revision --autogenerate` để tự động tạo script thay đổi.
3.  **Kiểm tra file Migration**: Mở file vừa tạo trong `backend/alembic/versions/` để đảm bảo code chính xác.
4.  **Cập nhật Database**: Dùng lệnh `alembic upgrade head` để áp dụng thay đổi vào Database thực tế.

---

## Các lệnh Alembic quan trọng

Bạn cần đứng ở thư mục `./backend` và kích hoạt Virtual Environment (nếu có) trước khi chạy lệnh.

### 1. Tạo file Migration tự động
Lệnh này sẽ so sánh sự khác biệt giữa các Model Python (`app/models`) và Database hiện tại để tạo ra file thay đổi.
```bash
alembic revision --autogenerate -m "mô tả thay đổi của bạn"
```
*Ví dụ:* `alembic revision --autogenerate -m "remove subject from course"`

### 2. Cập nhật Database lên bản mới nhất
Áp dụng tất cả các migration còn thiếu vào Database.
```bash
alembic upgrade head
```

### 3. Quay lại phiên bản trước (Rollback)
Nếu migration gặp lỗi, bạn có thể quay lại 1 bước:
```bash
alembic downgrade -1
```

### 4. Xem lịch sử các bản Migration
```bash
alembic history
```

---

## Ví dụ cụ thể: Xóa trường `subject` khỏi bảng `Course`

### Bước 1: Sửa Model (Đã thực hiện)
Trong file `backend/app/models/course.py`, chúng ta đã xóa dòng:
```python
subject: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
```

### Bước 2: Tạo Migration
Chạy lệnh sau trong terminal:
```bash
cd backend
alembic revision --autogenerate -m "remove subject from courses"
```

### Bước 3: Kiểm tra code Migration
Mở file mới nhất trong `backend/alembic/versions/`. Bạn sẽ thấy code dạng:
```python
def upgrade() -> None:
    # Xóa cột subject khỏi bảng courses
    op.drop_column('courses', 'subject')

def downgrade() -> None:
    # Thêm lại cột subject nếu muốn rollback
    op.add_column('courses', sa.Column('subject', sa.String(length=255), nullable=True))
```

### Bước 4: Chạy Upgrade
```bash
alembic upgrade head
```

---

## Lưu ý quan trọng

1.  **Backup trước khi Migrate**: Luôn chạy file `backup_before_migration.bat` (nếu có trong project) hoặc export database trước khi thực hiện các thay đổi lớn.
2.  **Đồng bộ Model và Schema**: Sau khi sửa Model, nếu không chạy migration, Backend sẽ bị lỗi khi cố gắng đọc/ghi vào các trường không tồn tại trong DB.
3.  **Docker**: Nếu bạn đang chạy ứng dụng qua Docker, hãy chạy lệnh alembic bên trong container:
    ```bash
    docker-compose exec backend alembic upgrade head
    ```

## Xử lý lỗi thường gặp

*   **"Target database is not up to date"**: Do bạn chưa chạy `alembic upgrade head` trước khi tạo migration mới. Hãy chạy upgrade trước.
*   **Lỗi khi Autogenerate không nhận diện được thay đổi**: Đảm bảo là bạn đã import Model mới vào file `backend/app/models/__init__.py` (hoặc nơi Alembic cấu hình `target_metadata`).
