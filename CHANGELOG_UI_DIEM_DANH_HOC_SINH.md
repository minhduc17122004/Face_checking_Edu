# 📋 Changelog: Chuyển đổi UI sang App Điểm Danh Học Sinh

> **Ngày thực hiện:** 06/02/2026  
> **Mục tiêu:** Thay đổi toàn bộ text, label, icon từ theme "Chấm công nhân viên" sang "Điểm danh học sinh", giữ nguyên 100% logic nghiệp vụ.

---

## 📌 Bảng Mapping Thuật Ngữ

| Thuật ngữ cũ (Nhân viên) | Thuật ngữ mới (Học sinh) |
|---------------------------|--------------------------|
| Nhân viên / Nhân sự | Học sinh |
| Chấm công | Điểm danh |
| Ca làm việc | Buổi học |
| Vào ca | Bắt đầu |
| Ra ca | Kết thúc |
| Chức vụ | Lớp |
| Checkout / Check-out | Điểm danh ra |
| Trễ giờ | Đến muộn |
| Paracel Tech | Điểm Danh Học Sinh |
| Smart Check In/Out Solution | Hệ thống điểm danh thông minh |

---

## 📁 Danh Sách File Đã Thay Đổi

### 1. `lib/pages/setting/setting_page.dart`
**Trang Cài đặt (Menu) — 10 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| Menu item 1 - title | "Danh Sách Chấm Công" | "Danh Sách Điểm Danh" |
| Menu item 1 - subtitle | "Xem danh sách nhân viên đã chấm công" | "Xem danh sách học sinh đã điểm danh" |
| Menu item 2 - title | "Đồng bộ dữ liệu chấm công" | "Đồng bộ dữ liệu điểm danh" |
| Menu item 2 - subtitle | "Đồng bộ dữ liệu chấm công hàng ngày" | "Đồng bộ dữ liệu điểm danh hàng ngày" |
| Menu item 4 - subtitle | "Đăng ký khuôn mặt để nhận diện" | "Đăng ký khuôn mặt học sinh" |
| Menu item 6 - title | "Thiết lập ca làm việc" | "Thiết lập buổi học" |
| Menu item 6 - subtitle | "Chọn thời gian làm việc cho từng ca" | "Chọn thời gian cho từng buổi học" |
| Dialog title | "Thiết lập ca làm việc" | "Thiết lập buổi học" |
| Dialog description | "Chọn thời gian cho từng ca làm việc:" | "Chọn thời gian cho từng buổi học:" |
| Table headers | Ca / Vào ca / Ra ca | Buổi / Bắt đầu / Kết thúc |
| Snackbar | "Đã lưu thiết lập ca làm việc" | "Đã lưu thiết lập buổi học" |

---

### 2. `lib/pages/employee/employee_page.dart`
**Trang Danh sách nhân viên → Danh sách học sinh — 7 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| Bottom sheet | "Đồng bộ nhân viên" | "Đồng bộ học sinh" |
| Bottom sheet | "Xóa tất cả nhân viên trong thiết bị" | "Xóa tất cả học sinh trong thiết bị" |
| Confirm dialog | "...đồng bộ tất cả nhân viên local..." | "...đồng bộ tất cả học sinh local..." |
| Item option | "Cập nhật chức vụ" | "Cập nhật lớp" |
| Delete dialog | '...xóa nhân viên "${name}"?' | '...xóa học sinh "${name}"?' |
| Edit dialog | "Cập nhật chức vụ" / "Chức vụ mới" | "Cập nhật lớp" / "Lớp mới" |
| Reset dialog | "...xóa TẤT CẢ dữ liệu nhân viên local?" | "...xóa TẤT CẢ dữ liệu học sinh local?" |

---

### 3. `lib/pages/employee/add_employee_dialog.dart`
**Dialog Thêm nhân viên → Thêm học sinh — 10 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| Success snackbar | "Thêm nhân viên thành công" | "Thêm học sinh thành công" |
| Error snackbar | "Lỗi thêm nhân viên" | "Lỗi thêm học sinh" |
| Catch error | "Lỗi thêm nhân viên: $e" | "Lỗi thêm học sinh: $e" |
| Dialog header | "Thêm Nhân Viên" | "Thêm Học Sinh" |
| Input label | "Tên Nhân Viên" | "Tên Học Sinh" |
| Validation 1 | "Vui lòng nhập tên nhân viên" | "Vui lòng nhập tên học sinh" |
| Validation 2 | "Tên nhân viên phải có ít nhất 2 ký tự" | "Tên học sinh phải có ít nhất 2 ký tự" |
| Input label | "Chức Vụ" | "Lớp" |
| Validation | "Vui lòng nhập chức vụ" | "Vui lòng nhập lớp" |
| Button text | "Thêm Nhân Viên" | "Thêm Học Sinh" |

---

### 4. `lib/pages/setting/attendance_report.dart`
**Trang Báo cáo điểm danh — 6 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| AppBar title | "Báo Cáo Chấm Công" | "Báo Cáo Điểm Danh" |
| Empty state title | "Không có dữ liệu chấm công" | "Không có dữ liệu điểm danh" |
| Empty state subtitle | "Chưa có bản ghi chấm công nào..." | "Chưa có bản ghi điểm danh nào..." |
| Table header | "Tên Nhân Sự" | "Tên Học Sinh" |
| Comment | // Tên Nhân Sự | // Tên Học Sinh |
| Dialog title | "Hình ảnh nhân viên" | "Hình ảnh học sinh" |

---

### 5. `lib/pages/checking/widgets/check_in_widget.dart`
**Widget kết quả check-in — 2 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| Label | "Nhân viên:" | "Học sinh:" |
| Status text | "Trễ giờ X phút" | "Đến muộn X phút" |

---

### 6. `lib/pages/checking/widgets/checkout_widget.dart`
**Widget kết quả check-out — 2 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| Result text | "${name} đã checkout" | "${name} đã điểm danh ra" |
| Label | "Check-out Time:" | "Thời gian ra:" |

---

### 7. `lib/pages/checking/widgets/user_info_component.dart`
**Widget thông tin user — 1 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| Field label | "Chức vụ" | "Lớp" |

---

### 8. `lib/pages/bootstrap/bootstrap_page.dart`
**Trang Splash/Bootstrap — 2 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| App name | "Paracel Tech" | "Điểm Danh Học Sinh" |
| Tagline | "Smart Check In/Out Solution" | "Hệ thống điểm danh thông minh" |

---

### 9. `lib/pages/register_face/register_face_page.dart`
**Trang Đăng ký khuôn mặt — 2 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| AppBar title | "NHÂN VIÊN" | "HỌC SINH" |
| Warning alert | "Cảnh báo chưa có mã nhân viên" | "Cảnh báo chưa có mã học sinh" |

---

### 10. `lib/pages/setting/cubit/setting/setting_cubit.dart`
**Cubit xử lý đồng bộ — 3 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| Success | "Đồng bộ nhân viên thành công" | "Đồng bộ học sinh thành công" |
| Failed | "Đồng bộ nhân viên thất bại" | "Đồng bộ học sinh thất bại" |
| Error | "Lỗi đồng bộ nhân viên: $e" | "Lỗi đồng bộ học sinh: $e" |

---

### 11. `lib/data/remote/user_service.dart`
**Service đồng bộ dữ liệu — 3 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| Success (empty) | "Đồng bộ nhân viên thành công" | "Đồng bộ học sinh thành công" |
| Success (full) | "Đồng bộ nhân viên thành công" | "Đồng bộ học sinh thành công" |
| Error | "Lỗi đồng bộ nhân viên: $e" | "Lỗi đồng bộ học sinh: $e" |

---

### 12. `lib/common/utils/sync_jobs_util.dart`
**Tiện ích đồng bộ nền — 2 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| Android sync message | "Đang đồng bộ nhân viên..." | "Đang đồng bộ học sinh..." |
| iOS sync message | "Đang đồng bộ nhân viên..." | "Đang đồng bộ học sinh..." |

---

### 13. `lib/utils/csv_util.dart`
**Xuất CSV/Excel — 2 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| CSV headers | ["Mã nhân sự", "Tên nhân sự", ...] | ["Mã học sinh", "Tên học sinh", ...] |
| Excel headers | ["Mã nhân sự", "Tên nhân sự", ...] | ["Mã học sinh", "Tên học sinh", ...] |

---

### 14. `lib/common/api_client/message_parser.dart`
**Bảng dịch lỗi API — 4 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| NOT_FOUND | "Không tìm thấy nhân viên..." | "Không tìm thấy học sinh..." |
| NOT_FOUND_OR_NOT_REGISTED | "Không tìm thấy nhân viên..." | "Không tìm thấy học sinh..." |
| NOT_CHECKIN | "Nhân viên chưa check in" | "Học sinh chưa điểm danh vào" |
| REGISTER.EXISTS | "...đăng ký bởi nhân viên khác" | "...đăng ký bởi học sinh khác" |

---

### 15. `lib/pages/employee/blocs/employee_bloc.dart`
**Bloc quản lý nhân viên — 2 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| Register error | "Lỗi khi đăng ký nhân viên: $e" | "Lỗi khi đăng ký học sinh: $e" |
| Delete error | "Lỗi khi xóa nhân viên: $e" | "Lỗi khi xóa học sinh: $e" |

---

### 16. `lib/pages/login_odoo/login_odoo_page.dart`
**Trang đăng nhập Odoo — 2 thay đổi**

| Vị trí | Trước | Sau |
|--------|-------|-----|
| Dialog title | "Đồng bộ dữ liệu nhân viên" | "Đồng bộ dữ liệu học sinh" |
| Dialog content | "Có dữ liệu nhân viên chưa được đồng bộ..." | "Có dữ liệu học sinh chưa được đồng bộ..." |

---

### 17. Localization Files — 4 thay đổi

| File | Trước | Sau |
|------|-------|-----|
| `l10n/intl_en.arb` | `"employee": "Nhân viên"` | `"employee": "Học sinh"` |
| `l10n/intl_en.arb` | `"rfidInfo": "...nhân viên."` | `"rfidInfo": "...học sinh."` |
| `generated/intl/messages_en.dart` | `"Nhân viên"` | `"Học sinh"` |
| `generated/l10n.dart` | `'Nhân viên'` / `'...nhân viên.'` | `'Học sinh'` / `'...học sinh.'` |

---

### 18. Android & Logging — 3 thay đổi

| File | Trước | Sau |
|------|-------|-----|
| `AndroidManifest.xml` | `android:label="Chấm công"` | `android:label="Điểm Danh"` |
| `logging_service.dart` | `app_name: "Chấm Công"` | `app_name: "Điểm Danh"` |
| `logging_model.dart` | `app_name="Chấm Công"` | `app_name="Điểm Danh"` |

---

## 📊 Tổng kết

| Thống kê | Số lượng |
|----------|----------|
| **Tổng số file đã sửa** | **18 files** |
| **Tổng số thay đổi text** | **~60+ chỗ** |
| **Logic bị ảnh hưởng** | **0 (không thay đổi)** |
| **Tên biến/class bị đổi** | **0 (giữ nguyên)** |

## ⚠️ Lưu ý

1. **Tên biến** như `employee`, `employeeName`, `EmployeeBloc`,... được **giữ nguyên** vì chỉ thay đổi UI text, không ảnh hưởng logic.
2. File `assets/dummy_form_data.json` chưa được sửa vì đây là dữ liệu mẫu/test, không hiển thị trực tiếp trong app.
3. Trang `home_page.dart` đã được cập nhật trước đó (Welcome → Xin chào, Chấm công → Điểm danh, thêm icon trường học).
