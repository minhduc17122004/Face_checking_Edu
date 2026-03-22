---
name: flutter-state-pattern
description: Flutter state management pattern cho dự án face_time_keeping. Sử dụng manual state classes với RequestStatus enum, Cubit (không dùng Freezed/Bloc events). Dùng khi tạo mới hoặc chỉnh sửa BLoC/Cubit, State, Entity, Service.
---

# Flutter State Pattern — face_time_keeping

## 1. Nguyên tắc cốt lõi

Dự án **KHÔNG dùng Freezed**, **KHÔNG dùng sealed class events**. Pattern:

- **State**: Manual class với `copyWith()` — giống `LoginState`
- **Logic**: `Cubit` extends `Cubit<T>` — giống `LoginBloc`
- **Status**: Enum `RequestStatus` (`initial`, `requesting`, `success`, `failed`)
- **Result**: `DataState<T>` với extension `isSuccess` trả về `bool`
- **DI**: `@injectable` trên Cubit, `@LazySingleton(as: T)` trên Service
- **Navigation**: `AppNavigator` + `RouterName` constants
- **Bloc Usage**: Lưu bloc làm member variable, KHÔNG dùng `context.read()`

---

## 2. State Pattern

### Template

```dart
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/xxx.dart';

class XxxState {
  final RequestStatus requestStatus;
  final List<Xxx> items;
  final String? message;
  final Xxx? selectedItem;

  XxxState({
    this.requestStatus = RequestStatus.initial,
    this.items = const [],
    this.message,
    this.selectedItem,
  });

  XxxState copyWith({
    RequestStatus? requestStatus,
    List<Xxx>? items,
    String? message,
    Xxx? selectedItem,
  }) {
    return XxxState(
      requestStatus: requestStatus ?? this.requestStatus,
      items: items ?? this.items,
      message: message,
      selectedItem: selectedItem ?? this.selectedItem,
    );
  }
}
```

### Quy tắc

1. **KHÔNG** dùng `@freezed`, `part 'xxx.freezed.dart'`
2. **KHÔNG** dùng `const factory` cho state variants
3. Luôn có `requestStatus` field (mặc định `RequestStatus.initial`)
4. Luôn có `copyWith()` method
5. `message` luôn là `String?`, reset bằng cách gán `message` không phải `copyWith`

---

## 3. Cubit Pattern

### Template

```dart
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/xxx_service.dart';
import 'package:face_time_keeping/pages/xxx/bloc/xxx_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@injectable
class XxxBloc extends Cubit<XxxState> {
  XxxBloc(this._xxxService) : super(XxxState());

  final XxxService _xxxService;

  Future<void> loadXxx() async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _xxxService.getXxx();
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        items: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed',
      ));
    }
  }

  Future<void> createXxx(...) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _xxxService.createXxx(...);
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedItem: result.data,
      ));
      await loadXxx();  // reload list
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed',
      ));
    }
  }
}
```

### Quy tắc

1. **`isSuccess`**: là extension method trên `DataState<T>`, KHÔNG phải property
2. **`result.data`**: luôn check null: `result.data ?? []`
3. **Sau khi tạo/sửa/xóa**: gọi `loadXxx()` để reload list
4. **Event methods**: đặt tên bằng verb: `loadXxx`, `createXxx`, `updateXxx`, `deleteXxx`
5. **KHÔNG** dùng sealed class cho events — methods trên Cubit thay thế

---

## 4. Page Pattern (Bloc Usage)

### Template — StatelessWidget + StatefulWidget

```dart
// ═══════════════════════════════════════════════════════════════
// Page entry: Tạo bloc bằng getIt và cung cấp qua BlocProvider.value
// ═══════════════════════════════════════════════════════════════

class XxxListPage extends StatelessWidget {
  const XxxListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Tạo bloc bằng getIt và gọi load() ngay
    final xxxBloc = getIt<XxxBloc>()..loadXxx();
    return BlocProvider.value(
      value: xxxBloc,
      child: _XxxListView(xxxBloc: xxxBloc),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// View: Nhận bloc qua constructor, dùng StatefulWidget để có setState
// ═══════════════════════════════════════════════════════════════

class _XxxListView extends StatefulWidget {
  final XxxBloc xxxBloc;

  const _XxxListView({required this.xxxBloc});

  @override
  State<_XxxListView> createState() => _XxxListViewState();
}

class _XxxListViewState extends State<_XxxListView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<XxxBloc, XxxState>(
        listener: (context, state) {
          if (state.requestStatus == RequestStatus.failed &&
              state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: SelectableText(state.message!),
                backgroundColor: AppColors.red600,
              ),
            );
          }
        },
        builder: (context, state) {
          // ... build UI based on state
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          AppNavigator.pushNamed(RouterName.xxxForm);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Actions: Gọi trực tiếp từ widget.bloc thay vì context.read()
  // ═══════════════════════════════════════════════════════════════

  void _showDeleteConfirmation(Xxx item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.xxxBloc.deleteXxx(item.id);  // ✅ Đúng
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _onSubmit() {
    widget.xxxBloc.createXxx(...);  // ✅ Đúng
  }
}
```

### Quy tắc Bloc Usage

1. **Tạo bloc**: `final bloc = getIt<XxxBloc>()..loadXxx();`
2. **Cung cấp bloc**: `BlocProvider.value(value: bloc, child: _View(bloc: bloc))`
3. **Nhận bloc**: Constructor parameter `required this.bloc`
4. **Gọi method**: `widget.bloc.method()` thay vì `context.read<XxxBloc>().method()`
5. **Lý do**: Tránh lỗi khi widget tree rebuild, giữ reference bloc ổn định

### ❌ Sai — KHÔNG làm như thế này

```dart
// ❌ SAI: Dùng context.read() trong callback
class _XxxListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<XxxBloc, XxxState>(
      builder: (context, state) {
        return ElevatedButton(
          onPressed: () {
            context.read<XxxBloc>().loadXxx();  // ❌ Nguy hiểm!
          },
        );
      },
    );
  }
}
```

### ✅ Đúng — Theo pattern của dự án

```dart
// ✅ ĐÚNG: Dùng widget.bloc
class _XxxListView extends StatefulWidget {
  final XxxBloc bloc;
  const _XxxListView({required this.bloc});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<XxxBloc, XxxState>(
      builder: (context, state) {
        return ElevatedButton(
          onPressed: () {
            widget.bloc.loadXxx();  // ✅ An toàn
          },
        );
      },
    );
  }
}
```

---

## 5. Entity Pattern

### Template

```dart
class Xxx {
  final String id;
  final String name;
  final DateTime createdAt;

  const Xxx({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Xxx.fromJson(Map<String, dynamic> json) {
    return Xxx(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {...};

  Xxx copyWith({String? name}) => Xxx(
    id: id, name: name ?? this.name, createdAt: createdAt,
  );
}
```

### Quy tắc

1. Dùng `const constructor` khi có thể
2. Luôn có `fromJson` và `toJson`
3. Backend field names: snake_case → convert sang camelCase trong `fromJson`
4. Timestamps: dùng `DateTime.parse()`

---

## 6. Service Pattern

### Template

```dart
import 'package:face_time_keeping/common/api_client/api_client.dart';
import 'package:face_time_keeping/common/api_client/api_response.dart';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:injectable/injectable.dart';
import '../../entities/xxx.dart';

abstract class XxxService {
  Future<DataState<List<Xxx>>> getXxx();
  Future<DataState<Xxx>> createXxx(...);
}

@LazySingleton(as: XxxService)
class XxxServiceImplement implements XxxService {
  XxxServiceImplement(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<DataState<List<Xxx>>> getXxx() async {
    try {
      final response = await _apiClient.get(path: '/api/v1/xxx');
      if (response.isSuccess()) {
        final data = response.data['items'] as List? ?? [];
        return DataSuccess<List<Xxx>>(data.map((e) => Xxx.fromJson(e)).toList());
      }
      return DataFailed<List<Xxx>>(response.error);
    } on DioError catch (e) {
      return DataFailed<List<Xxx>>(e.message);
    }
  }
}
```

### Quy tắc

1. **`@LazySingleton(as: XxxService)`** trên implementation
2. **`@injectable`** trên Cubit
3. Luôn wrap response trong `DataSuccess` hoặc `DataFailed`
4. Backend errors: dùng `response.error` (String?)
5. Network errors: dùng `e.message`

---

## 7. Navigation Pattern

### RouterName Constants

```dart
// lib/route/app_route.dart
class RouterName {
  static const String home = '/home';
  static const String login = '/login';
  static const String xxxList = '/xxx';
  static const String xxxForm = '/xxx/form';
  static const String xxxDetail = '/xxx/detail';
  // ... thêm routes mới vào đây
}
```

### AppNavigator Methods

```dart
import 'package:face_time_keeping/route/navigator.dart';

// Navigate to page
AppNavigator.pushNamed(RouterName.xxxDetail, arguments: item);

// Navigate and remove all previous pages
AppNavigator.pushNamedAndRemoveUntil(RouterName.home, (_) => false);

// Go back
AppNavigator.pop();

// Go back with result
AppNavigator.pop(true);
```

### Quy tắc Navigation

1. **KHÔNG dùng hardcoded string** cho route: dùng `RouterName.xxx`
2. **KHÔNG dùng `Navigator.of(context).push()`** trực tiếp
3. **Luôn import** cả `RouterName` và `AppNavigator`
4. **Đặt route mới** trong `app_route.dart` class `RouterName`

---

## 8. Dependency Injection

### Đăng ký Service

```dart
@LazySingleton(as: XxxService)
class XxxServiceImplement implements XxxService {...}
```

### Đăng ký Cubit

```dart
@injectable
class XxxBloc extends Cubit<XxxState> {...}
```

### Sử dụng

```dart
final bloc = getIt<XxxBloc>();
```

### Quan trọng

- **KHÔNG** viết tay `injection.config.dart` — file này được generate tự động
- Chạy `dart run build_runner build --delete-conflicting-outputs` sau khi tạo mới Service/Cubit
- Hoặc chạy `flutter pub run build_runner build --delete-conflicting-outputs`

---

## 9. DataState Pattern

```dart
// Extension method trên DataState
// KHÔNG phải property
if (result.isSuccess) {  // ✅ đúng
  // ...
}
if (result.success) {   // ❌ sai
  // ...
}
```

### Result handling

```dart
// Thành công
return DataSuccess<T>(data);

// Thất bại (backend error)
return DataFailed<T>(response.error);

// Thất bại (network error)
return DataFailed<T>(e.message);
```

---

## 10. RequestStatus Enum

```dart
enum RequestStatus { initial, requesting, success, failed }
```

### Ý nghĩa

| Giá trị | Dùng khi |
|---------|----------|
| `initial` | Trạng thái ban đầu, chưa có action |
| `requesting` | Đang gọi API, hiển thị loading |
| `success` | API thành công, có data |
| `failed` | API thất bại, hiển thị error message |

---

## 11. Checklist trước khi commit

- [ ] KHÔNG có `part 'xxx.freezed.dart'` trong state files
- [ ] KHÔNG có sealed class cho events
- [ ] Tất cả files có `isSuccess` dùng đúng extension method
- [ ] Bloc được tạo bằng `getIt<XxxBloc>()..loadXxx()` và truyền qua constructor
- [ ] KHÔNG dùng `context.read<XxxBloc>()` trong callbacks — dùng `widget.bloc`
- [ ] Navigation dùng `RouterName.xxx` constants thay vì hardcoded strings
- [ ] Chạy `build_runner` sau khi tạo mới Service/Cubit
- [ ] Test bằng cách check linter: `flutter analyze lib/pages/xxx`
