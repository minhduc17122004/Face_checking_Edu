# Báo cáo Tính năng: Trang cá nhân (Profile)

Tài liệu này tóm tắt các thay đổi và cập nhật cho trang cá nhân (Profile) trong ứng dụng Flutter và Backend.

## 1. Giao diện người dùng (Frontend)

Trang `ProfilePage` (`lib/pages/account/profile_page.dart`) đã được cập nhật để hiển thị thông tin chi tiết từ hệ thống:

- **Thông tin cơ bản**: Hiển thị Avatar (với fallback là chữ cái đầu của tên), Họ tên, và Vai trò (Student/Teacher/Admin).
- **Thông tin chi tiết**:
    - **Email**: Luôn hiển thị.
    - **Mã định danh**: Hiển thị "Mã sinh viên" đối với Student hoặc "Mã cán bộ" đối với Teacher.
    - **Tổ chức**: Hiển thị "Lớp" đối với Student hoặc "Môn dạy" đối với Teacher.
- **Tính năng**:
    - Sử dụng `FutureBuilder` để tải dữ liệu từ `/api/v1/auth/me`.
    - Hỗ trợ `RefreshIndicator` (vuốt xuống để tải lại).
    - Giao diện hiện đại với `AppColors` chuẩn, card trắng bo góc và đổ bóng nhẹ.

## 2. API Backend & Cấu trúc dữ liệu

Để hỗ trợ hiển thị đầy đủ thông tin, Backend đã được nâng cấp:

- **Schema cập nhật**: `UserInfo` Pydantic model (`backend/app/schemas/v1/auth.py`) bổ sung trường `student_code` và `class_name`.
- **Model User mở rộng**: Thêm các `@property` sinh động (`student_code`, `class_name`) vào `User` model (`backend/app/models/user.py`) để tự động lấy dữ liệu từ các profile liên quan (`student_profile`, `teacher_profile`) mà không cần thay đổi cấu trúc bảng cũ.
- **Xử lý đăng ký mới**: `UserRepository.create()` (`backend/app/repositories/user_repository.py`) được cập nhật để:
    - Lưu `pin` thành `student_code`.
    - Tự động tìm kiếm hoặc tạo mới `StudentGroup` từ `job_title` gửi lên để gán vào `class_name`.
- **Độ tin cậy cao**: Bổ sung `try...except` để bắt lỗi `MissingGreenlet` của SQLAlchemy, đảm bảo luồng đăng ký không bị lỗi 500 khi quan hệ dữ liệu chưa kịp nạp (lazy load).

## 3. Cách kiểm tra dữ liệu

- **Đối với tài khoản cũ**: Nếu `student_profile` hoặc `student_group` chưa được khởi tạo trong DB, Dashboard sẽ tự động ẩn các dòng thông tin thiếu.
- **Đối với tài khoản mới**: Thông tin điền tại màn hình Đăng ký (`pin` -> mã số, `job_title` -> tên lớp) sẽ được tự động hiển thị đầy đủ ngay sau khi đăng nhập.

---
*Ngày cập nhật: 21/03/2026*
