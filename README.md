# Vedura - EDU Attendance

A Flutter-based educational attendance management system with face recognition for tracking student attendance in schools, universities, and training centers.

## Features

- Face recognition attendance with liveness detection
- Multi-role support (Admin, Teacher, Student)
- Course & session management
- Device-based classroom attendance
- Offline support with background sync
- PIN security for sensitive operations
- Student group management
- CSV/Excel report export

## Tech Stack

- **Flutter** 3.5.0+ / **Dart** 3.5.0+
- **State Management**: flutter_bloc, get_it, injectable
- **Local Storage**: Hive, shared_preferences
- **Face Recognition**: google_mlkit_face_detection, face_native, liveness_detection_plugin
- **Networking**: Dio, cookie_jar
- **Background Tasks**: Workmanager

## Architecture

Clean Architecture with separation of concerns:

```
lib/
├── common/         # Shared utilities, resources, event bus
├── configs/        # Environment configuration
├── data/           # Data layer (local/remote services)
├── di/             # Dependency injection
├── entities/       # Domain entities
├── pages/          # UI screens by feature
├── route/          # Navigation
└── utils/          # Helpers
```

## Screens

| Module | Features |
|--------|----------|
| **Login** | Email/password auth with JWT |
| **Home** | Dashboard, quick check-in, recent activity |
| **Attendance** | Face scanning, check-in/out, session selection |
| **Teacher** | Session management, manual check-in, course students |
| **Admin** | Device/room/course/student management, reports |
| **Settings** | Profile, PIN security, face registration, reports |

## Environments

```bash
# Run
flutter run --dart-define=ENVIRONMENT=dev   # dev
flutter run --dart-define=ENVIRONMENT=test   # staging
flutter run --dart-define=ENVIRONMENT=prod   # production

# Build Android
flutter build apk --dart-define=ENVIRONMENT=dev
flutter build appbundle --dart-define=ENVIRONMENT=prod

# Build iOS
flutter build ipa --release --dart-define=ENVIRONMENT=prod
```

## Code Generation

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

## Offline Support

- Hive local database caching
- Pending attendance queue for offline recording
- Background sync with Workmanager
- Pre-cached student face data

## Security

- JWT authentication with token refresh
- 6-digit PIN protection (max 5 attempts)
- Encrypted local storage
- Secure asset encryption keys

## Requirements

- Flutter SDK: 3.5.0+
- Android SDK: 21+
- iOS: 12.0+
- Camera permission required
