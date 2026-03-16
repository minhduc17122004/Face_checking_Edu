# Tài liệu: Cơ chế lưu trữ dữ liệu trên thiết bị

> **Phiên bản:** face_time_keeping  
> **Ngày cập nhật:** 2026-03-07  
> **Mục tiêu:** Mô tả chi tiết cách ứng dụng lưu trữ, truy xuất và quản lý dữ liệu trên thiết bị (on-device storage).

---

## Tổng quan kiến trúc

Ứng dụng sử dụng **4 tầng lưu trữ** kết hợp, mỗi tầng phục vụ một mục đích khác nhau:

```
┌─────────────────────────────────────────────────────────────┐
│                        LocalService                          │
│          (Façade – điều phối toàn bộ storage)               │
└────────┬──────────────┬──────────────┬───────────────────────┘
         │              │              │
    SharedPrefs       Hive         face_native
  (key-value)    (structured)    (ObjectBox - native)
         │              │              │
  Cài đặt/Auth   Chấm công/      Face embeddings
                  Nhân viên/
                   Tenant
                              +─────────────────┐
                              │   File System    │
                              │ (CSV/Excel/JSON) │
                              └─────────────────┘
```

Toàn bộ storage được truy cập thông qua **`LocalService`** — một `@LazySingleton` được inject qua `get_it`. Lớp này kết hợp `SharedPrefs`, `HiveService` và `FaceNative` thành một interface duy nhất cho toàn ứng dụng.

---

## 1. SharedPreferences

**Package:** `shared_preferences: ^2.0.15`  
**Wrapper:** `lib/data/local/keychain/shared_prefs.dart` (`SharedPrefs`)  
**Khai báo key:** `lib/data/local/keychain/shared_prefs_key.dart` (`SharedPrefsKey`)

### Mục đích
Lưu các giá trị đơn giản dạng key-value (String, int, double, bool, List\<String\>). Phù hợp cho **cài đặt ứng dụng**, **thông tin xác thực**, và **trạng thái session**.

### Danh sách key và kiểu dữ liệu

| Key (constant) | Tên biến | Kiểu | Mô tả |
|---|---|---|---|
| `token` | `token` | `String` | JWT/access token đăng nhập Odoo |
| `userId` | `userId` | `int` | ID user trên server |
| `loginId` | `loginId` | `String` | Username đăng nhập Odoo |
| `domain` | `domain` | `String` | URL server Odoo (ví dụ: `https://demo.odoo.com`) |
| `dbName` | `dbName` | `String` | Tên database Odoo |
| `tenantId` | `tenantId` | `int` | ID tenant đang hoạt động (khoá chính phân tách dữ liệu Hive) |
| `licenseKey` | `licenseKey` | `String` | License key thiết bị (mã hoá base64) |
| `pinApp` | `pinApp` | `String` | Mã PIN bảo vệ ứng dụng |
| `morningTime` | `morningTime` | `String` | Thời gian ca sáng (serialized JSON) |
| `afternoonTime` | `afternoonTime` | `String` | Thời gian ca chiều (serialized JSON) |
| `nightTime` | `nightTime` | `String` | Thời gian ca tối (serialized JSON) |
| `syncSchedules` | `syncSchedules` | `String` | JSON array của `SyncSchedule` (lịch sync chấm công lên server) |
| `syncFaceSchedule` | `syncFaceSchedule` | `String` | JSON object của `SyncFaceSchedule` (lịch sync dữ liệu khuôn mặt) |
| `latestTimePullFaceData` | `latestTimePullFaceData-{tenantId}` | `String` | ISO-8601 timestamp lần cuối pull face data từ server (per-tenant) |
| `isInitializedDefaultData` | `isInitializedDefaultData` | `bool` | Đánh dấu đã chạy khởi tạo dữ liệu mặc định chưa |
| `serverType` | `serverType` | `String` | Loại server kết nối (`odoo`, `mis`, ...) |
| `tempServerType` | `tempServerType` | `String` | Loại server tạm (khi đang thay đổi cài đặt) |
| `savedCookied` | `savedCookied` | `String` | Cookie session của server |
| `devices` | `devices` | `String` | Thông tin thiết bị |
| `logs` | `logs` | `String` | Log nội bộ ứng dụng |

### Đặc điểm key per-tenant
Một số key được **suffix bởi tenantId** để tránh xung đột khi thiết bị phục vụ nhiều công ty:

```dart
// Ví dụ: "latestTimePullFaceData-42"
Future<String> _formatWithTenantId(String key) async {
  final tenantId = await getTenantId();
  return '$key-$tenantId';
}
```

### API wrapper (`SharedPrefs`)
```dart
// Đọc
final token = _sharedPreferences.get<String>(SharedPrefsKey.token);

// Ghi
await _sharedPreferences.put<String>(SharedPrefsKey.token, value);

// Xoá 1 key
await _sharedPreferences.clearKey(SharedPrefsKey.pinApp);

// Xoá toàn bộ
await _sharedPreferences.clear();
```

---

## 2. Hive (NoSQL Database)

**Package:** `hive: ^2.2.3` + `hive_flutter: ^1.1.0`  
**Code generator:** `hive_generator: ^2.0.1`  
**Service:** `lib/data/local/hive_service.dart` (`HiveService` / `HiveServiceImplement`)

### Mục đích
Lưu trữ dữ liệu có cấu trúc dạng object: bản ghi chấm công, danh sách nhân viên, thông tin tenant. Hive là database **NoSQL dạng key-value với type-safe**, lưu trực tiếp Dart object.

### Kiến trúc multi-tenant
Mỗi tenant có **box riêng biệt** được đặt tên theo pattern `{boxName}-{tenantId}`:

```
tenant_box               ← dùng chung, không phân tách
checkIO_box-{tenantId}   ← riêng từng tenant
person_box-{tenantId}    ← riêng từng tenant
```

**Khởi tạo khi đăng nhập:**
```dart
// Trong LoginOdooBloc.onLogin()
await FaceNative().initObjectBox(tenantId.toString());
await getIt<HiveService>().init(tenantId.toString());
```

### 2.1 Box: `tenant_box`

**Entity:** `Tenant` (`lib/entities/tenant.dart`) — `@HiveType(typeId: 6)`

| HiveField | Tên field | Kiểu | Mô tả |
|---|---|---|---|
| 0 | `id` | `int?` | Khoá tự sinh (auto-increment key của Hive) |
| 1 | `url` | `String` | URL server Odoo |
| 2 | `databaseName` | `String` | Tên database |

**Mục đích:** Lưu danh sách các server/database mà thiết bị đã từng đăng nhập. Khi đăng nhập lại cùng một `url + dbName`, hệ thống tái sử dụng `tenantId` cũ thay vì tạo mới.

**Các thao tác chính:**
- `addTenant(tenant)` → tạo tenant mới, trả về key
- `getTenantId(url, dbName)` → tra cứu tenant theo url + dbName

### 2.2 Box: `checkIO_box-{tenantId}`

**Entity:** `CheckInOut` (`lib/entities/check_in_out.dart`) — `@HiveType(typeId: 0)`

| HiveField | Tên field | Kiểu | Mô tả |
|---|---|---|---|
| — | `id` | `int?` | Khoá tự sinh của Hive (gán khi lưu) |
| 0 | `employeeId` | `int` | ID nhân viên (từ server) |
| 1 | `pin` | `String?` | Mã PIN nhân viên (không là khoá chính) |
| 2 | `name` | `String` | Tên nhân viên tại thời điểm chấm |
| 3 | `time` | `DateTime` | Thời gian chấm công |
| 4 | `imagePath` | `String?` | Đường dẫn ảnh snapshot khuôn mặt |
| 5 | `isSynced` | `bool` | `true` nếu đã đẩy thành công lên server |
| 6 | `isCheckIn` | `bool` | `true` = check-in, `false` = check-out |
| 7 | `latitude` | `double?` | Vĩ độ GPS |
| 8 | `longitude` | `double?` | Kinh độ GPS |

**Luồng ghi/đọc:**
1. Nhân viên chấm công → `saveCheckInOut(checkInOut)` → ghi vào Hive với `isSynced = false`
2. Background job (Workmanager) chạy → `getUnSyncedCheckInOuts()` → lấy danh sách chưa sync
3. Push lên Odoo API thành công → `updateCheckInOutFlag(ioId, true)` → đánh dấu `isSynced = true`

**Export:**
- `getCheckInOutsOnOrAfter(date)` → lọc theo ngày → export CSV/Excel qua `CsvUtil`

### 2.3 Box: `person_box-{tenantId}`

**Entity:** `Person` (`lib/entities/person.dart`) — `@HiveType(typeId: 2)`

| HiveField | Tên field | Kiểu | Mô tả |
|---|---|---|---|
| 0 | `employeeId` | `int` | ID nhân viên (khoá chính, đồng bộ từ server) |
| 1 | `updatedTime` | `DateTime` | Thời gian cập nhật dữ liệu khuôn mặt lần cuối |
| 2 | `isSynced` | `bool` | `true` nếu face embedding đã được server xác nhận |
| 3 | `pin` | `String?` | Mã PIN đăng nhập |
| 4 | `name` | `String?` | Tên hiển thị |
| 5 | `jobTitle` | `dynamic` | Chức danh |
| 6 | `avatar` | `String?` | Base64 hoặc path ảnh đại diện |

**Mục đích:** Index nhân viên đã đăng ký khuôn mặt + trạng thái sync với ObjectBox.

**Luồng ghi:**
- Pull từ server → `syncEmployeesFromServer()` → upsert vào Hive
- Import face data từ file JSON → `importFaceData()` → cập nhật `updatedTime` trong Hive

### Clone dữ liệu khi đổi tenant
Khi người dùng đăng nhập vào một tổ chức khác (tenantId mới), dữ liệu được **clone sang box mới** thay vì xoá:

```dart
// Trong LoginOdooBloc.onLogin()
if (oldTenantId != -1 && oldTenantId != tenantId) {
  await _localService.cloneDataFromPreviousTenant(oldTenantId, tenantId);
}

// HiveService.cloneDataFromOldTenant()
// → copy toàn bộ Person và CheckInOut từ box cũ sang box mới
// → đánh dấu isSynced = false để buộc re-sync
// → xoá box cũ
```

---

## 3. ObjectBox (qua plugin `face_native` — Native Layer)

**Plugin:** `face_native` (package local tại `packages/` hoặc native plugin)  
**Khởi tạo:** `FaceNative().initObjectBox(tenantId.toString())`  
**Nền tảng:** Android only (guard bởi `if (Platform.isAndroid)`)

### Mục đích
Lưu **face embeddings** (vector đặc trưng khuôn mặt — `List<double>`) trực tiếp ở tầng native (Kotlin + ObjectBox). Việc tách lớp này giúp:
- Nhận diện khuôn mặt **100% offline**, không cần server
- Hiệu năng cao khi tra cứu (ObjectBox là database Dart/Kotlin có chỉ mục tối ưu)
- Tách biệt dữ liệu biometric nhạy cảm ra khỏi Hive

### Entity: `FaceImageRecord`

| Field | Kiểu | Mô tả |
|---|---|---|
| `empId` | `int` | ID nhân viên |
| `personName` | `String` | Tên (metadata) |
| `faceEmbedding` | `List<double>` | Vector đặc trưng khuôn mặt (128 hoặc 512 chiều tuỳ model) |

### API của FaceNative

| Phương thức | Mô tả |
|---|---|
| `initObjectBox(tenantId)` | Khởi tạo database ObjectBox cho tenant |
| `addImage(record)` | Thêm 1 face embedding |
| `addAllRecords(records)` | Thêm nhiều face embeddings cùng lúc |
| `removeImages(empId)` | Xoá toàn bộ ảnh của 1 nhân viên |
| `removeImagesByIds(ids)` | Xoá theo danh sách ID |
| `getAllImages()` | Lấy toàn bộ records |
| `getImageIdsByEmpId(empId)` | Lấy danh sách ID ảnh theo nhân viên |
| `getFaceImageRecordByListEmpId(ids)` | Lấy records theo danh sách empId |

### Luồng đăng ký khuôn mặt
```
RegisterFaceBloc.onCapture()
  → _faceNative.addImage(FaceImageRecord(empId, embedding))
  → Lưu empId vào Hive (Person.isSynced = false)

RegisterFaceBloc.onConfirm()
  → đánh dấu đăng ký hoàn tất
  → Workmanager sync Face → server
```

### Luồng import/export face data (JSON)
```
// Export (backup/transfer)
exportModelToJsonFile()
  → _faceNative.getAllImages()           ← lấy từ ObjectBox
  → serialize thành List<FaceData>
  → ghi ra file JSON tạm trong tmp directory

// Import (restore)
importFromJsonFile(path)
  → đọc file JSON
  → parse thành List<FaceImageRecord>
  → _faceNative.addAllRecords(list)      ← lưu vào ObjectBox
```

---

## 4. File System (Tạm thời / Export)

**Package:** `path_provider` + `share_plus`

### Mục đích
Xuất dữ liệu ra file để chia sẻ hoặc backup. Không dùng cho lưu trữ lâu dài — file được tạo trong **temporary directory** và bị hệ điều hành dọn dẹp.

### Các loại file được tạo

| Loại | Phương thức | Tên file | Nội dung |
|---|---|---|---|
| CSV | `exportCheckInOutToCsv(date)` | Auto-generated | Danh sách chấm công từ Hive |
| Excel | `exportCheckInOutToExcel(date)` | Auto-generated | Danh sách chấm công từ Hive |
| JSON | `exportModelToJsonFile()` | `face_data_{timestamp}.json` | Face embeddings từ ObjectBox |

**Vị trí lưu:**
```dart
final tempDir = await getTemporaryDirectory();
// Android: /data/user/0/{packageName}/cache/
// iOS:     /var/mobile/Containers/Data/Application/{uuid}/tmp/
```

---

## 5. Sơ đồ luồng dữ liệu tổng thể

### Luồng chấm công (offline-first)
```
Nhân viên chấm công
    │
    ▼
[Nhận diện khuôn mặt]
    │ FaceNative.verify() → so sánh với ObjectBox
    │
    ▼
[Lưu bản ghi]
    │ HiveService.saveCheckInOut()
    │ → checkIO_box-{tenantId}, isSynced = false
    │
    ▼
[Background Workmanager - mỗi 30 phút]
    │ HiveService.getUnSyncedCheckInOuts()
    │ LocalService.getBulkUsers()
    │     │
    │     ▼ Gọi Odoo API
    │
    ▼
[Nhận SyncResponse]
    │ HiveService.updateCheckInOutFlag(ioId, isSynced: true)
    └─── Bản ghi được đánh dấu đã sync
```

### Luồng đồng bộ nhân viên (face data)
```
[Background Workmanager - mỗi 15 phút]
    │
    ▼
Pull từ Odoo API (FaceData list)
    │ latestTimePullFaceData → chỉ lấy record mới hơn
    │
    ▼
LocalService.importFaceData(faceDataList)
    │
    ├─── FaceNative.removeImages(empId)     ← xoá embedding cũ (ObjectBox)
    ├─── FaceNative.addAllRecords(records)  ← thêm embedding mới (ObjectBox)
    └─── HiveService.updatePerson(newPerson) ← cập nhật metadata (Hive)
         + saveLatestTimePullFaceData()       ← cập nhật watermark (SharedPrefs)
```

### Luồng đăng nhập & khởi tạo tenant
```
Người dùng nhấn Login
    │
    ▼
AuthenticationService.login()
    │
    ▼
SharedPrefs ← lưu token, userId, loginId, serverType
    │
    ▼
HiveService.getTenantId(url, dbName)
    │ tìm trong tenant_box
    │ nếu không có → addTenant() → tạo mới
    │
    ▼
SharedPrefs ← saveTenantId(tenantId)
    │
    ▼
FaceNative.initObjectBox(tenantId)    ← mở ObjectBox store cho tenant
HiveService.init(tenantId)            ← mở checkIO_box & person_box cho tenant
    │
    ▼ (nếu đổi tenant)
HiveService.cloneDataFromOldTenant()  ← chuyển data từ tenant cũ
```

---

## 6. Quản lý vòng đời dữ liệu

### Xoá dữ liệu (`clearAllData`)
```dart
// Khi logout hoặc reset ứng dụng
_hiveService.clearCheckInOut()   // xoá bản ghi chấm công
_hiveService.clearPersons()      // xoá danh sách nhân viên
_sharedPreferences.clear()       // xoá toàn bộ SharedPrefs
// FaceNative: cần gọi removeImages() per-person
```

### Refresh box (sau khi đổi tenant)
```dart
await _hiveService.refreshCheckInOutBox();
await _hiveService.refreshPersonBox();
// Đóng box cũ → mở box mới với tenantKey hiện tại
```

---

## 7. Bảo mật

| Dữ liệu | Biện pháp bảo mật |
|---|---|
| Access token | Lưu SharedPreferences — **không mã hoá** (native layer bảo vệ bởi sandboxing) |
| PIN app | Lưu SharedPreferences dạng plain text — nên xem xét dùng `flutter_secure_storage` |
| Face embeddings | Lưu ObjectBox (native) — trong app sandbox, không thể truy cập từ app khác |
| License key | Lưu SharedPreferences, encode base64 (không phải mã hoá thực sự) |
| GPS coordinates | Lưu cùng bản ghi chấm công trong Hive |

> ⚠️ **Lưu ý bảo mật:** PIN và token đang được lưu dưới dạng plaintext trong SharedPreferences. Cân nhắc migrate sang `flutter_secure_storage` cho các dữ liệu nhạy cảm này.

---

## 8. Dependency Injection

Tất cả storage service được đăng ký qua `get_it` + `injectable`:

```dart
// SharedPrefs — lazySingleton
@lazySingleton
class SharedPrefs { ... }

// HiveService — lazySingleton
@LazySingleton(as: HiveService)
class HiveServiceImplement implements HiveService { ... }

// LocalService — lazySingleton (kết hợp cả hai)
@LazySingleton(as: LocalService)
class LocalServiceImplement implements LocalService {
  LocalServiceImplement(
    this._sharedPreferences,  // inject SharedPrefs
    this._apiClient,
    this._hiveService,        // inject HiveService
    this._csvUtil,
  );
}
```

---

## 9. Tham chiếu file nhanh

| Mục đích | File |
|---|---|
| Interface LocalService | `lib/data/local/local_service.dart` |
| HiveService | `lib/data/local/hive_service.dart` |
| SharedPrefs wrapper | `lib/data/local/keychain/shared_prefs.dart` |
| Khai báo key | `lib/data/local/keychain/shared_prefs_key.dart` |
| Entity CheckInOut | `lib/entities/check_in_out.dart` |
| Entity Person | `lib/entities/person.dart` |
| Entity Tenant | `lib/entities/tenant.dart` |
| Entity FaceData | `lib/entities/face_data.dart` |
| Khởi tạo storage khi login | `lib/pages/login_odoo/bloc/login_odoo_bloc.dart` |
| Background sync jobs | `lib/common/utils/sync_jobs_util.dart` |
| AppSingleton (access token) | `lib/utils/app_singleton.dart` |
