---
name: face-time-keeping-dev
description: Guidelines for developing features in the Face Time Keeping project. Covers architecture (Bloc, Clean Architecture), Dependency Injection (Injectable), Local Storage (Hive), and Face Recognition integration.
---

# Face Time Keeping Development

## Overview

This project is a Flutter application for timekeeping using face recognition and location validation. It uses a Clean Architecture approach with **BloC** for state management, **Injectable** for dependency injection, **Hive** for local storage, and **Google ML Kit** for face detection.

## Tech Stack

*   **Framework**: Flutter
*   **State Management**: `flutter_bloc`
*   **Dependency Injection**: `injectable`, `get_it`
*   **Networking**: `dio`, `retrofit` (likely, or direct Dio usage)
*   **Local Storage**: `hive`
*   **Face Detection**: `google_mlkit_face_detection`, `face_native`
*   **Navigation**: `go_router` or custom Navigator (See `lib/route`)
*   **Utils**: `equatable`, `json_annotation`

## Project Structure

```
lib/
├── common/             # Shared constants, extensions, widgets
├── configs/            # Build configurations (environments)
├── data/               # Data Layer
│   ├── local/          # Hive DAOs, SharedPrefs
│   ├── remote/         # API Clients, Endpoints
│   ├── models/         # DTOs (Data Transfer Objects)
│   └── cron_job.dart   # Background jobs (Workmanager)
├── di/                 # Dependency Injection Setup (injection.dart)
├── entities/           # Domain Entities (often Hive annotated)
├── localization/       # l10n and generated strings
├── pages/              # Presentation Layer (SCREENS)
│   └── [feature]/      # e.g., home, login_odoo
│       ├── bloc/       # Logic for the feature
│       └── [page].dart # UI Widget
├── route/              # Navigation configuration
└── main.dart           # App Entry point
```

## Development Workflow

### 1. Create Data/Domain Logic

**Entity (`lib/entities/`)**:
Define your business object. If it needs to be persisted locally, add Hive annotations.

```dart
import 'package:hive/hive.dart';
part 'employee.g.dart';

@HiveType(typeId: 1)
class Employee extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;

  Employee({required this.id, required this.name});
}
```

**Repository/Service**:
Use `@injectable` or `@singleton` to register services.

```dart
import 'package:injectable/injectable.dart';

@lazySingleton
class EmployeeRepository {
  final ApiClient _apiClient; // Injected via constructor
  
  EmployeeRepository(this._apiClient);

  Future<List<Employee>> getEmployees() async {
    // Implementation
  }
}
```

### 2. Create UI & Logic (Bloc)

**Bloc (`lib/pages/[feature]/bloc`)**:
Create Event, State, and Bloc classes. Use `freezed` or `equatable` for states.

```dart
// employee_event.dart
abstract class EmployeeEvent extends Equatable {
  @override
  List<Object> get props => [];
}
class FetchEmployees extends EmployeeEvent {}

// employee_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@injectable
class EmployeeBloc extends Bloc<EmployeeEvent, EmployeeState> {
  final EmployeeRepository _repo;

  EmployeeBloc(this._repo) : super(EmployeeInitial()) {
    on<FetchEmployees>(_onFetchEmployees);
  }

  Future<void> _onFetchEmployees(FetchEmployees event, Emitter<EmployeeState> emit) async {
    emit(EmployeeLoading());
    try {
      final data = await _repo.getEmployees();
      emit(EmployeeLoaded(data));
    } catch (e) {
      emit(EmployeeError(e.toString()));
    }
  }
}
```

**Page (`lib/pages/[feature]/`)**:
Wrap your view in `BlocProvider`. Use `getIt<T>()` to inject the Bloc if needed, or let `injectable` handle it if structured correctly.

```dart
class EmployeePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<EmployeeBloc>()..add(FetchEmployees()),
      child: Scaffold(
        appBar: AppBar(title: Text('Employees')),
        body: BlocBuilder<EmployeeBloc, EmployeeState>(
          builder: (context, state) {
            if (state is EmployeeLoading) return CircularProgressIndicator();
            if (state is EmployeeLoaded) return ListView(...) // Build list
            return Container();
          },
        ),
      ),
    );
  }
}
```

### 3. Dependency Injection
Run the generator after making changes to `@Injectable` classes:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Background Sync (Workmanager)
See `lib/data/cron_job.dart` (or `SyncJobsUtil` in `main.dart`) for background task registration. This is crucial for syncing attendance data when the app is in the background.

## Common Tasks

### Adding a new Route
1.  Open `lib/route/app_route.dart` (or similar).
2.  Add a static string for the route path.
3.  Register the route in the router configuration.

### running the App
*   **Prod**: `flutter run --dart-define=ENVIRONMENT=prod`
*   **Dev**: `flutter run --dart-define=ENVIRONMENT=dev`

## Best Practices

*   **Logic Separation**: Keep UI dumb. Move logic to Bloc.
*   **DI**: Always use `getIt` or constructor injection. Avoid `new Class()`.
*   **Hive**: Remember to register adapters in `main.dart` if you add new Hive types.
*   **Assets**: Put images/icons in `assets/` and run `flutter pub get` (if using an asset generator).
