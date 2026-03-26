Dưới đây là bản **điều chỉnh plan của bạn** theo chiến lược **Hybrid (online-first + offline fallback)**.
Giữ nguyên structure của bạn, chỉ **chỉnh sửa + bổ sung những phần cần thiết để production-ready**.

---

# EDU Checking Flow — Implementation Plan (Revised - Hybrid Architecture)

## 🔥 Key Strategy Update

> The system follows **online-first with offline fallback queue**:

* Backend is the **single source of truth**
* Local storage (Hive) is used only for:

  * temporary buffering (offline)
  * retry mechanism
* No business logic (late, session validation) is executed on client

---

## 1. Entity Layer (UPDATED)

### ✅ Keep existing

* `EduCheckIn` → vẫn dùng cho UI

---

### ➕ [NEW] `pending_edu_check_in.dart` (CRITICAL)

```dart
class PendingEduCheckIn {
  final String id;              // UUID
  final int studentId;
  final int? sessionId;         // nullable when offline
  final DateTime timestamp;
  final String? imagePath;

  final bool isSynced;
  final int retryCount;

  final double? latitude;
  final double? longitude;
}
```

### 🎯 Purpose

* Thay thế hoàn toàn `CheckInOut` trong context EDU
* Là **offline queue buffer**
* Không chứa business logic

---

## 2. BLoC Layer (UPDATED CORE FLOW)

### 🔁 Update `edu_checking_bloc.dart`

#### OLD FLOW

```
Face → API → Done
```

#### NEW FLOW (Hybrid)

```
Face → Try API
        │
        ├── SUCCESS → Emit result (normal)
        │
        └── FAIL (network)
              ↓
        Save PendingEduCheckIn (Hive)
              ↓
        Emit "Pending sync" UI state
```

---

### ➕ Add new state

```dart
bool isOfflineMode;
bool hasPendingSync;
```

---

### ➕ Add new event (important)

```dart
syncPendingCheckIns()
```

---

## 3. Storage Layer (NEW - REUSE HRM STRENGTH)

### ➕ Hive Box

```
pending_edu_checkin_box-{tenantId}
```

---

### ➕ LocalService APIs

```dart
Future<void> savePendingEduCheckIn(PendingEduCheckIn item);

Future<List<PendingEduCheckIn>> getPendingCheckIns();

Future<void> markAsSynced(String id);

Future<void> increaseRetryCount(String id);
```

---

## 4. Background Sync (CRITICAL ADDITION)

### ❗ Reuse Workmanager (từ HRM)

#### New job:

```
syncPendingEduCheckIns()
```

### Flow:

```
Get pending list
    ↓
Call API (manualCheckin)
    ↓
SUCCESS → mark isSynced = true
FAIL → retryCount++
```

---

### 🔒 Backend requirement (IMPORTANT)

API must support:

```
POST /attendance/check-in

Body:
{
  studentId,
  sessionId (optional),
  timestamp
}
```

👉 Backend tự:

* map session nếu null
* tính late
* validate window

---

## 5. UI Layer (SMALL BUT IMPORTANT CHANGE)

### ➕ Add trạng thái mới

* ✅ Success
* ⏳ Pending (offline)
* ❌ Failed

---

### UX Suggestion (rất quan trọng)

| Case           | UI                       |
| -------------- | ------------------------ |
| Online success | Normal result            |
| Offline        | "Đã lưu, sẽ đồng bộ sau" |
| Sync success   | Silent                   |
| Sync fail      | Optional retry indicator |

---

## 6. Key Design Decisions (UPDATED)

| Aspect           | Final Decision                 |
| ---------------- | ------------------------------ |
| Storage          | Hybrid (API + Hive fallback)   |
| Sync             | Direct API + Workmanager retry |
| Session logic    | Backend only                   |
| Late detection   | Backend only                   |
| Face recognition | Offline (FaceNative)           |
| Offline support  | Yes (queue-based)              |

---

## 7. Critical Rules (MUST FOLLOW)

### ❌ KHÔNG làm

* Không tính late ở client
* Không chọn session ở client (offline)
* Không reuse `CheckInOut`

---

### ✅ PHẢI làm

* Client chỉ gửi:

  ```
  studentId + timestamp
  ```
* Backend quyết định toàn bộ logic

---

## 8. Edge Cases Handling (NEW)

### Case 1: Offline → Sync trễ

* Backend xử lý bằng:

  * grace window (VD: +10 phút)

---

### Case 2: Duplicate check-in

* Backend reject hoặc idempotent

---

### Case 3: Sai session

* Backend auto map theo timestamp

---

## 9. Minimal Impact Guarantee

✔ Không đụng HRM module
✔ Không phá flow hiện tại
✔ Chỉ **add thêm layer fallback**

---

## 10. Final Architecture (Mental Model)

```
          ┌──────────────┐
          │ FaceNative   │ (offline)
          └──────┬───────┘
                 ↓
         ┌──────────────┐
         │ EDU Bloc     │
         └──────┬───────┘
                ↓
        ┌───────────────┐
        │ API (Primary) │
        └──────┬────────┘
               │ fail
               ↓
        ┌───────────────┐
        │ Hive Queue    │
        └──────┬────────┘
               ↓
        ┌───────────────┐
        │ Workmanager   │
        └───────────────┘
```

---

## 11. Tại sao bản này tốt hơn (quan trọng)

| Tiêu chí          | Plan cũ          | Plan mới       |
| ----------------- | ---------------- | -------------- |
| Reliability       | ❌ phụ thuộc mạng | ✅ chịu lỗi tốt |
| Data consistency  | ✅                | ✅              |
| Offline support   | ❌                | ✅              |
| Reuse hệ thống cũ | ❌                | ✅              |
| Production ready  | ⚠️               | ✅              |

---

## 12. Kết luận

Plan ban đầu của bạn:

> **đúng hướng về business (EDU)**
> nhưng:
> **thiếu resilience (offline + retry)**

Bản revised này:

> giữ logic EDU + thêm “xương sống” của HRM

---

Nếu muốn nâng cấp tiếp level production, bước tiếp theo nên làm:

* API idempotency (tránh duplicate)
* Sync priority queue (retry thông minh)
* Monitoring (log sync fail)

Chỉ cần nói, có thể giúp bạn thiết kế luôn backend contract chuẩn production.
