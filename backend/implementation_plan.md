# Implementation Plan: Device-Based Attendance Management

## Tóm tắt
Hệ thống đã triển khai phần lớn cơ sở hạ tầng (backend models, device request flow, room-session listing, attendance check-in). Tuy nhiên, có **6 gaps chính** cần bổ sung để hoàn thiện theo yêu cầu [attendance_management.md](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/attendance_management.md).

---

## Gap Analysis — Hiện trạng vs Yêu cầu

| # | Yêu cầu | Hiện trạng | Trạng thái |
|---|---------|-----------|-----------|
| 1 | Device phải được cấp quyền mới truy cập điểm danh; popup yêu cầu nếu chưa cấp | ✅ [DeviceRequestSubmitPage](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/setting/device_request_submit_page.dart#15-21) đã có popup + submit request. [DevicePermissionPage](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/setting/device_permission_page.dart#11-23) cho admin duyệt | **Đã có** |
| 2 | Admin gán device cho phòng; chỉ admin mới duyệt | ✅ Backend [DeviceRequest](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/backend/app/models/device_request.py#18-109) có `room_id`. Setting page chỉ hiện admin features khi `_isAdmin=true`. Tuy nhiên khi approve **chưa gán room** | ⚠️ **Thiếu gán room khi approve** |
| 3 | Khi được cấp quyền, hiển thị danh sách phòng → sessions (sắp theo thời gian gần nhất) → vào checking nếu trong time window | ⚠️ [RoomSessionPage](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/room/room_session_page.dart#14-28) đã có flow Room→Sessions→[AttendanceCheckinPage](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/attendance_checkin/attendance_checkin_page.dart#21-37). Nhưng **chưa kết nối từ Setting → danh sách phòng được cấp phép** | ⚠️ **Thiếu flow Setting→authorized rooms** |
| 4 | Checking hiển thị tên học phần + số lượng đã điểm danh; trạng thái early/late theo AttendanceConfig | ⚠️ [AttendanceCheckinPage](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/attendance_checkin/attendance_checkin_page.dart#21-37) đã hiển thị tên + count. Nhưng [checking_page.dart](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/checking/checking_page.dart) dùng luồng HR cũ (face→local Hive) chưa integrate session-based attendance config | ⚠️ **checking_page chưa dùng session-based config** |
| 5 | History tab filter theo role (admin:all, teacher:course, student:self) | ❌ Tab "Lịch sử" đang là placeholder `Đang phát triển`. Chưa có API `GET /attendance/history` role-based | ❌ **Chưa triển khai** |
| 6 | Sync thông tin điểm danh lên server theo DATA_STORAGE.md | ⚠️ Có legacy `POST /api/attendance/history/sync_bulk_io` + v1 `POST /api/v1/attendance/check-in`. Local Hive sync qua Workmanager nhưng chưa connect tới v1 API | ⚠️ **Cần connect sync** |

---

## Proposed Changes

### Component 1: Backend — Attendance History API

> [!IMPORTANT]
> Endpoint mới `GET /api/v1/attendance/history` — role-based filtering là tính năng core.

#### [NEW] attendance_history (in [attendance.py](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/backend/app/routers/v1/attendance.py))

Thêm endpoint:
```python
@router.get("/history", response_model=AttendanceHistoryList)
async def get_attendance_history(
    role: str,           # admin / teacher / student
    user_id: str,        # from JWT
    course_id: Optional[UUID] = None,
    skip: int = 0,
    limit: int = 50,
):
```
- **admin**: trả tất cả attendance records (có join session→course để lấy tên)  
- **teacher**: lọc theo `course.teacher_id == user.teacher_id`
- **student**: lọc theo `attendance.student_id == user.student_id`

#### [MODIFY] [attendance.py](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/backend/app/routers/v1/attendance.py)
- Thêm schema `AttendanceHistoryItem` + `AttendanceHistoryList`

#### [MODIFY] [attendance_service.py](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/backend/app/services/attendance_service.py)
- Thêm method `get_history(role, user_id, ...)` với query logic

---

### Component 2: Backend — Device Request Approve + Room Assignment

#### [MODIFY] [device_request_service.py](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/backend/app/services/device_request_service.py)
- Khi approve: nếu request có `room_id`, tự động cập nhật `device.room_id = request.room_id`
- Đảm bảo tạo/update [Device](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/backend/app/models/device.py#19-123) record tương ứng

#### [MODIFY] [device_requests.py](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/backend/app/routers/v1/device_requests.py)
- API approve cho phép truyền `room_ids: List[UUID]` (gán nhiều phòng)

---

### Component 3: Flutter — Setting → Authorized Rooms Flow

#### [MODIFY] [device_request_submit_page.dart](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/setting/device_request_submit_page.dart)
- Khi `isAuthorized == true`: hiển thị danh sách phòng được cấp phép (lấy từ API `GET /api/v1/devices/me`)
- Nhấn phòng → navigate [RoomSessionPage](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/room/room_session_page.dart#14-28)
- [RoomSessionPage](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/room/room_session_page.dart#14-28) đã có logic time-window + navigate tới [AttendanceCheckinPage](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/attendance_checkin/attendance_checkin_page.dart#21-37)

#### [MODIFY] [device_permission_cubit.dart](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/setting/cubit/device_permission/device_permission_cubit.dart)
- Thêm method `loadAuthorizedRooms()` → gọi API lấy danh sách room

---

### Component 4: Flutter — Checking Page Session Integration

#### [MODIFY] [checking_page.dart](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/checking/checking_page.dart)
- Thêm `sessionId` vào [CheckingArgs](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/checking/checking_page.dart#18-27)
- Hiển thị tên học phần (từ session) và số lượng đã điểm danh ở header
- Sau face recognition thành công → gọi `POST /api/v1/attendance/check-in` với session context

#### [MODIFY] [checking_bloc.dart](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/checking/bloc/checking_bloc.dart)
- Thêm session-aware checkin: sử dụng [AttendanceConfig](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/backend/app/models/attendance_config.py#16-83) (early_allowance, late_allowance) để xác định status
- [_checkInLocal()](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/checking/bloc/checking_bloc.dart#153-192): tính `minutes_diff = checkin_time - session.start_time`, áp dụng config per-session
- Song song lưu local (Hive cho offline) + sync server (khi có kết nối)

#### [MODIFY] [checking_state.dart](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/checking/bloc/checking_state.dart)
- Thêm fields: `courseName`, `attendanceCount`, `totalEnrolled`, `sessionId`

---

### Component 5: Flutter — History Tab

#### [NEW] `lib/pages/history/attendance_history_page.dart`
- Trang chính hiển thị lịch sử điểm danh
- Filter tự động theo role từ `AppBloc`:
  - **admin**: hiển thị tất cả, filter theo course/date
  - **teacher**: hiển thị courses của giáo viên đó
  - **student**: chỉ hiển thị records của mình

#### [NEW] `lib/pages/history/bloc/attendance_history_bloc.dart`
- Cubit quản lý state cho history page
- Gọi API `GET /api/v1/attendance/history`

#### [NEW] `lib/data/remote/attendance_history_service.dart`
- API service gọi endpoint history

#### [MODIFY] [tab.dart](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/tab/tab.dart)
- Replace placeholder `Center(child: Text("Lịch sử (Đang phát triển)"))` → `AttendanceHistoryPage()`

---

### Component 6: Attendance Sync Flow

#### [MODIFY] [local_service.dart](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/data/local/local_service.dart)
- Trong [checkIn()](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/checking/bloc/checking_bloc.dart#153-192): thêm session_id vào CheckInOut record
- Sync job: sử dụng v1 API `POST /api/v1/attendance/check-in` thay vì legacy endpoint

---

## User Review Required

> [!WARNING]
> **Breaking change**: [checking_page.dart](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/lib/pages/checking/checking_page.dart) flow sẽ thay đổi từ HR-style (face→Hive only) sang session-based (face→Hive + API sync). Luồng cũ check-in/check-out sẽ bị thay thế bằng session-based checkin. Cần xác nhận: có cần giữ backward compatibility với luồng HR cũ không?

> [!IMPORTANT]
> **Device multi-room**: Hiện tại [Device](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/backend/app/models/device.py#19-123) model có 1 `room_id`. Yêu cầu ghi "gán quyền điểm danh cho từng phòng" — cần bảng trung gian `device_rooms` (many-to-many) thay vì field `room_id` đơn lẻ. Hoặc dùng `is_global=true` + nhiều [DeviceRequest](file:///c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/backend/app/models/device_request.py#18-109) records (mỗi request 1 room). Xin ý kiến chọn cách nào?

---

## Verification Plan

### Build Verification
```bash
# Backend
cd face_time_keeping/backend
python -m pytest tests/ -v

# Flutter 
cd face_time_keeping
flutter analyze
flutter build apk --debug
```

### Manual Verification
1. **Kiểm tra device request flow**: Mở app → Setting → "Quản lý điểm danh thiết bị" → thấy popup yêu cầu cấp quyền → gửi request → đăng nhập admin → Setting → "Yêu cầu quyền thiết bị" → approve với room
2. **Kiểm tra authorized rooms list**: Sau khi approve, vào lại "Quản lý điểm danh thiết bị" → thấy danh sách phòng được cấp phép
3. **Kiểm tra room → session flow**: Nhấn vào phòng → thấy danh sách session → session trong time window có nút "Điểm danh"
4. **Kiểm tra checking page**: Vào session → thấy tên học phần + count → face scan → check status early/late
5. **Kiểm tra History tab**: Nhấn tab "Lịch sử" → admin thấy all, teacher thấy own courses, student thấy own records
