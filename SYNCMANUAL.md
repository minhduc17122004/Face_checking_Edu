# Tài liệu Chức Năng Đồng Bộ — Face Time Keeping

> **Phiên bản:** 1.0
> **Ngày:** 23/03/2026
> **Dự án:** face_time_keeping

---

## Mục lục

1. [Tổng quan](#1-tổng-quan)
2. [Ba loại đồng bộ](#2-ba-loại-đồng-bộ)
3. [Đồng bộ dữ liệu khuôn mặt](#3-đồng-bộ-dữ-liệu-khuôn-mặt)
4. [Đồng bộ dữ liệu điểm danh](#4-đồng-bộ-dữ-liệu-điểm-danh)
5. [Đồng bộ dữ liệu học sinh](#5-đồng-bộ-dữ-liệu-học-sinh)
6. [Giao diện đồng bộ trong ứng dụng](#6-giao-diện-đồng-bộ-trong-ứng-dụng)
7. [Mô hình dữ liệu & Entity](#7-mô-hình-dữ-liệu--entity)
8. [Các file quan trọng](#8-các-file-quan-trọng)
9. [Lưu ý trước khi triển khai](#9-lưu-ý-trước-khi-triển-khai)

---

## 1. Tổng quan

Ứng dụng Face Time Keeping hỗ trợ **3 loại đồng bộ** giữa thiết bị Flutter và backend server. Mỗi loại phục vụ một mục đích riêng biệt:

| # | Loại đồng bộ | Mô tả | Có upload khuôn mặt? |
|---|---|---|---|
| 1 | **Đồng bộ dữ liệu khuôn mặt** | Đồng bộ vector đặc trưng khuôn mặt | ✅ **Có** |
| 2 | **Đồng bộ dữ liệu điểm danh** | Upload bản ghi điểm danh offline | ❌ Không |
| 3 | **Đồng bộ dữ liệu học sinh** | Đồng bộ thông tin & ảnh đại diện học sinh | ✅ Upload ảnh đại diện |

---

## 2. Ba loại đồng bộ

### 2.1 Đồng bộ dữ liệu khuôn mặt

**Chức năng:** Đồng bộ vector đặc trưng khuôn mặt (face embedding) giữa thiết bị và server.

**Cách hoạt động:**

- **Push (thiết bị → server):** Ứng dụng lấy danh sách người chưa được đồng bộ (`getPersonsUnSynced()`), xuất vector đặc trưng ra file JSON tạm, sau đó upload lên server qua `PUT /api/student/update/embedding`. Sau khi upload thành công, đánh dấu đã đồng bộ (`setPersonSynced()`).

- **Pull (server → thiết bị):** Gọi `GET /api/student/export/json`, nhận danh sách vector khuôn mặt từ server, import vào engine nhận diện khuôn mặt cục bộ (`_localService.importFaceData()`), lưu lại thời điểm đồng bộ cuối cùng.

**Điều quan trọng:** Ứng dụng upload **không phải ảnh khuôn mặt gốc**, mà là vector đặc trưng 128 chiều. Ảnh khuôn mặt được xử lý cục bộ bằng thư viện `FaceNative` để tạo ra các vector số, chỉ có vector mới được gửi lên server.

**Lên lịch:** Mặc định chạy định kỳ **15 phút/lần**, có thể cấu hình khoảng thời gian tùy ý.

### 2.2 Đồng bộ dữ liệu điểm danh

**Chức năng:** Upload các bản ghi điểm danh (check-in/check-out) đã lưu offline lên server.

**Cách hoạt động:**

- Lấy danh sách bản ghi điểm danh chưa đồng bộ từ bộ nhớ cục bộ
- Gửi payload `bulk_users` lên `POST /api/attendance/history/sync_bulk_io`
- Server trả về trạng thái từng bản ghi, ứng dụng đánh dấu đã đồng bộ tương ứng
- **Không upload khuôn mặt**, chỉ gửi thông tin thời gian và mã học sinh

**Lên lịch:** Chạy định kỳ theo cấu hình trong `SyncSchedule`.

### 2.3 Đồng bộ dữ liệu học sinh

**Chức năng:** Đồng bộ danh sách học sinh (thông tin, ảnh đại diện) giữa thiết bị và server.

**Cách hoạt động:**

- Lấy danh sách học sinh chưa đồng bộ
- Nếu có ảnh đại diện (file ảnh cục bộ), upload ảnh trước qua `POST /api/student/avatars/upload`
- Tạo bản ghi học sinh qua `POST /api/student/create/batch` kèm `uploadId` của ảnh
- Pull toàn bộ học sinh từ server về qua `GET /api/student/get_all_students`

---

## 3. Đồng bộ dữ liệu khuôn mặt — Chi tiết kỹ thuật

### 3.1 Luồng Push (thiết bị → server)

```
Thiết bị Flutter                          Backend
      │                                       │
      │  1. getPersonsUnSynced()              │
      │     (lấy danh sách người chưa sync)   │
      │                                       │
      │  2. _localService.exportModelToJsonFile()
      │     (xuất vector → file JSON tạm)     │
      │                                       │
      │  3. PUT /api/student/update/embedding │
      │     (multipart/form-data) ────────────►│
      │                                       │  4. Lưu vector vào DB
      │                                       │     (face_service.import_from_file)
      │                                       │
      │  5. setPersonSynced()                  │
      │     (đánh dấu đã sync)                │
```

### 3.2 Luồng Pull (server → thiết bị)

```
Thiết bị Flutter                          Backend
      │                                       │
      │  1. GET /api/student/export/json      │
      │     (có thể kèm ?from_date=...) ──────►│
      │                                       │  2. Lấy tất cả embeddings
      │                                       │     (face_service.export_all)
      │  3. Trả về JSON FaceDataOut           │◄──
      │◄──────────────────────────────────────│
      │
      │  4. _localService.importFaceData()
      │     (nạp vector vào engine FaceNative)
      │
      │  5. Lưu thời điểm sync cuối cùng
```

### 3.3 Định dạng dữ liệu khuôn mặt

Dữ liệu gửi/nhận tuân theo model `FaceData`:

| Trường | Kiểu | Mô tả |
|---|---|---|
| `empId` | String | Mã học sinh |
| `name` | String | Tên học sinh |
| `listEmbedding` | List[float] | Danh sách vector 128 chiều (mỗi vector là một lần đăng ký) |
| `updatedTime` | DateTime | Thời điểm cập nhật cuối |

---

## 4. Đồng bộ dữ liệu điểm danh — Chi tiết kỹ thuật

```
Thiết bị Flutter                          Backend
      │                                       │
      │  1. Lấy bản ghi điểm danh chưa sync   │
      │     từ bộ nhớ cục bộ                  │
      │                                       │
      │  2. POST /api/attendance/history/      │
      │     sync_bulk_io                      │
      │     (payload: bulk_users) ───────────►│
      │                                       │  3. Xử lý từng bản ghi
      │                                       │     (lưu vào DB)
      │  4. Trả về trạng thái mỗi bản ghi     │◄──
      │◄──────────────────────────────────────│
      │
      │  5. Đánh dấu đã đồng bộ theo kết quả
```

---

## 5. Đồng bộ dữ liệu học sinh — Chi tiết kỹ thuật

```
Thiết bị Flutter                          Backend
      │                                       │
      │  1. Lấy học sinh chưa sync            │
      │                                       │
      │  2. Có ảnh? → POST /api/student/      │
      │     avatars/upload ───────────────────►│
      │                                       │  3. Lưu ảnh, trả về uploadId
      │  4. uploadId ◄─────────────────────────│
      │                                       │
      │  5. POST /api/student/create/batch    │
      │     (kèm uploadId) ──────────────────►│
      │                                       │  6. Tạo bản ghi học sinh
      │                                       │
      │  7. GET /api/student/get_all_students  │
      │     (pull về local) ─────────────────►│
```

---

## 6. Giao diện đồng bộ trong ứng dụng

### 6.1 Trang Cài đặt (Setting Page)

File: `lib/pages/setting/setting_page.dart`

#### Nút đồng bộ khuôn mặt

- **Nút:** "Đồng bộ dữ liệu khuôn mặt"
- **Hành động:** Mở hộp thoại với 2 lựa chọn:
  1. **"Đồng bộ dữ liệu ngay"** — Gọi `pushFaceData()` rồi `pullFaceData()` ngay lập tức
  2. **"Đồng bộ định kỳ"** — Mở cấu hình khoảng thời gian (giờ + phút), lưu qua `saveSyncFaceSchedule()`

#### Nút đồng bộ điểm danh

- **Nút:** "Đồng bộ dữ liệu điểm danh"
- **Hành động:** Gọi `syncCheckInOutData()` để upload bản ghi điểm danh offline

#### Nút cấu hình đồng bộ

- **Nút:** "Thiết lập đồng bộ dữ liệu"
- **Hành động:** Mở trang `SyncSchedulePage` để thêm/xóa lịch đồng bộ điểm danh

### 6.2 Trang Lịch đồng bộ (Sync Schedule Page)

File: `lib/pages/setting/sync_schedule_page.dart`

- Cho phép thêm/xóa nhiều thời điểm đồng bộ
- Sử dụng `scheduleSyncData()` để đăng ký và `cancelSyncData()` để hủy
- Lưu trong `LocalService` qua `SharedPreferences`

### 6.3 Cubit quản lý trạng thái

File: `lib/pages/setting/cubit/setting/setting_cubit.dart`

| Hàm | Mô tả |
|---|---|
| `pushFaceData()` | Upload vector khuôn mặt lên server |
| `pullFaceData()` | Tải vector khuôn mặt về thiết bị |
| `syncCheckInOutData()` | Upload bản ghi điểm danh |
| `syncLocalStudentsToServer()` | Upload danh sách học sinh |
| `getSyncFaceSchedule()` | Đọc lịch đồng bộ khuôn mặt |
| `saveSyncFaceSchedule()` | Lưu lịch đồng bộ khuôn mặt |
| `clearSyncFaceSchedule()` | Xóa lịch đồng bộ khuôn mặt |

---

## 7. Mô hình dữ liệu & Entity

### 7.1 Person Entity

File: `lib/entities/person.dart`

Trường `isSynced` theo dõi trạng thái đồng bộ của từng người. Người chưa sync được lấy qua `getPersonsUnSynced()` trong `LocalService`.

### 7.2 SyncFaceSchedule Entity

File: `lib/entities/sync_face_schedule.dart`

Mô hình cấu hình lịch đồng bộ khuôn mặt, bao gồm khoảng thời gian (số giờ + số phút).

### 7.3 FaceData Entity

File: `lib/entities/face_data.dart`

Mô hình dữ liệu vector khuôn mặt (empId, name, listEmbedding, updatedTime).

### 7.4 Backend Models

| File | Mô tả |
|---|---|
| `backend/app/models/face_embedding.py` | Model database lưu vector 128 chiều |
| `backend/app/schemas/v1/time_slot.py` | Schema API response cho time slots |

---

## 8. Các file quan trọng

### Phía Flutter (Frontend)

| File | Mô tả |
|---|---|
| `lib/common/utils/sync_jobs_util.dart` | Bộ lập lịch sync nền dùng Workmanager |
| `lib/data/remote/user_service.dart` | Tất cả API call đồng bộ (push/pull face, check-in/out, students) |
| `lib/data/remote/api_endpoint.dart` | Định nghĩa URL endpoint API |
| `lib/data/local/local_service.dart` | Thao tác lưu trữ cục bộ (lấy chưa sync, import face, export JSON) |
| `lib/pages/setting/setting_page.dart` | Giao diện nút đồng bộ khuôn mặt & điểm danh |
| `lib/pages/setting/sync_schedule_page.dart` | Giao diện cấu hình lịch đồng bộ |
| `lib/entities/person.dart` | Entity người với trường `isSynced` |
| `lib/entities/face_data.dart` | Model dữ liệu vector khuôn mặt |
| `lib/entities/sync_face_schedule.dart` | Model cấu hình lịch sync |

### Phía Backend

| File | Mô tả |
|---|---|
| `backend/app/routers/legacy_router.py` | Endpoint API cho Flutter (embedding upload/export, attendance sync, student CRUD) |
| `backend/app/services/face_service.py` | Logic xử lý import/export vector khuôn mặt |
| `backend/app/models/face_embedding.py` | Model database ORM cho face embedding |
| `backend/app/routers/v1/time_slots.py` | API router cho time slots (12 periods) |

---

## 9. Lưu ý trước khi triển khai

### 9.1 Yêu cầu hệ thống

1. **Backend server phải đang chạy** — FastAPI service cần hoạt động để các API endpoint đồng bộ có thể truy cập được
2. **Kết nối mạng** — Đồng bộ phụ thuộc vào kết nối mạng giữa thiết bị Flutter và server
3. **Thiết bị có bộ nhớ đủ** — File JSON tạm chứa vector khuôn mặt cần đủ dung lượng lưu trữ

### 9.2 Chuẩn bị dữ liệu ban đầu

1. **Đăng ký khuôn mặt** — Cần đăng ký khuôn mặt cho học sinh trước qua admin hoặc trực tiếp trên thiết bị
2. **Push dữ liệu ban đầu** — Sau khi đăng ký, chạy sync để upload vector lên server
3. **Pull dữ liệu** — Các thiết bị khác cần pull để nhận dữ liệu khuôn mặt về

### 9.3 Cấu hình đồng bộ

1. **Khoảng thời gian sync** — Mặc định 15 phút, có thể điều chỉnh tùy nhu cầu:
   - Khoảng ngắn hơn → dữ liệu đồng bộ nhanh hơn nhưng tốn pin/mạng hơn
   - Khoảng dài hơn → tiết kiệm tài nguyên nhưng dữ liệu có thể chậm cập nhật
2. **Sync thủ công** — Người dùng có thể bấm "Đồng bộ dữ liệu ngay" bất kỳ lúc nào

### 9.4 Những gì KHÔNG có trong hệ thống

- ❌ **Không có Firebase** — Toàn bộ sync đều qua backend API tự phát triển
- ❌ **Không upload ảnh khuôn mặt gốc** — Chỉ upload vector đặc trưng 128 chiều
- ❌ **Không dùng Google Drive** — Không có cloud storage bên thứ ba
- ❌ **Không sync khi offline hoàn toàn** — Cần có mạng để gọi API, dù có lưu cache offline

### 9.5 Quy trình đồng bộ khuyến nghị cho trường học

```
Bước 1: Admin đăng ký khuôn mặt cho tất cả học sinh
         ↓
Bước 2: Chạy "Đồng bộ dữ liệu khuôn mặt" (Push) trên thiết bị chính
         ↓
Bước 3: Cài đặt app trên các thiết bị học sinh
         ↓
Bước 4: Các thiết bị chạy Pull để nhận dữ liệu khuôn mặt
         ↓
Bước 5: Bật đồng bộ định kỳ (khuyến nghị 15-30 phút)
         ↓
Bước 6: Kiểm tra đồng bộ điểm danh hàng ngày
```

---

## 10. Các endpoint API

### Đồng bộ khuôn mặt

| Method | Endpoint | Mô tả |
|---|---|---|
| `PUT` | `/api/student/update/embedding` | Upload file JSON chứa vector khuôn mặt |
| `GET` | `/api/student/export/json` | Export toàn bộ vector khuôn mặt (hỗ trợ `?from_date=`) |

### Đồng bộ điểm danh

| Method | Endpoint | Mô tả |
|---|---|---|
| `POST` | `/api/attendance/history/sync_bulk_io` | Upload batch bản ghi điểm danh |

### Đồng bộ học sinh

| Method | Endpoint | Mô tả |
|---|---|---|
| `POST` | `/api/student/avatars/upload` | Upload ảnh đại diện học sinh |
| `POST` | `/api/student/create/batch` | Tạo batch học sinh |
| `GET` | `/api/student/get_all_students` | Lấy danh sách tất cả học sinh |
