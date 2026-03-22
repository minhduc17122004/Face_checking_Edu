# Login/Logout Feature Report

- Date: 2026-03-17
- Branch: `feature/login_out`
- Scope: Flutter app + FastAPI backend auth migration and stabilization

## 1) Goal

This feature migrated login/logout from the legacy domain-dependent flow to the new FastAPI backend auth flow.

Main goals:
- Use backend auth APIs (`/auth/login`, `/auth/logout`, `/auth/me`) as source of truth.
- Remove hard dependency on Odoo domain in core login path.
- Stabilize network/auth error handling on Android emulator and real devices.
- Prevent UI crash caused by forced navigation on login 401 responses.

## 2) Delivered Scope

### 2.1 Backend feature implementation

Implemented and validated backend auth feature updates:

- Added stateless logout endpoint:
  - `POST /auth/logout`
  - Files:
    - `backend/app/routers/auth_router.py`
    - `backend/app/services/auth_service.py`
    - `backend/app/schemas/auth_schema.py`

- Auth service behavior:
  - `register`: validates duplicate email, hashes password, returns JWT token payload.
  - `login`: validates credentials, returns JWT token payload.
  - `me`: resolves user from JWT subject (`sub`).
  - `logout`: stateless API for client-side session synchronization.

- Security and compatibility stabilization:
  - Updated password context to support robust hashing and backward verification:
    - `backend/app/core/security.py`
    - `CryptContext(schemes=["bcrypt_sha256", "bcrypt"], deprecated="auto")`
  - Pinned bcrypt to compatible version to avoid runtime register/login failures in container:
    - `backend/requirements.txt`
    - `bcrypt==4.0.1`

- Backend startup/serialization compatibility fix included in branch:
  - Pydantic v2 root-model adjustment in face schema to avoid API startup/runtime errors:
    - `backend/app/schemas/face_schema.py`

### 2.2 Flutter feature implementation

Implemented and validated Flutter-side auth migration:

- API endpoint and service integration:
  - Added auth endpoints and logout endpoint usage:
    - `lib/data/remote/api_endpoint.dart`
    - `lib/data/remote/authentication_service.dart`

- Base URL migration and non-domain bootstrapping:
  - Runtime base URL from dart-define (`API_BASE_URL`) with normalization:
    - `lib/configs/build_config.dart`
  - Boot/login flow prefers configured base URL over legacy domain storage:
    - `lib/pages/bootstrap/bootstrap_cubit.dart`
    - `lib/data/local/local_service.dart`
    - `lib/pages/login/bloc/login_bloc.dart`

- API client resiliency:
  - Added guard for relative path requests when base URL is missing.
  - Added clearer timeout guidance for `10.0.2.2` vs real device LAN usage.
  - Reduced recursive remote logging during network failures.
  - File:
    - `lib/common/api_client/api_client.dart`

- Interceptor and navigation safety:
  - Prevented forced logout/navigation when 401 comes from auth endpoints (login/logout).
  - Added re-entry guard to avoid repeated navigation reset race.
  - File:
    - `lib/common/api_client/interceptors/auth_interceptor.dart`

- Logout flow behavior:
  - Call backend logout API, then clear local auth state even if remote call fails.
  - File:
    - `lib/pages/setting/cubit/setting/setting_cubit.dart`

- Added runtime diagnostics in login flow:
  - File:
    - `lib/pages/login/bloc/login_bloc.dart`

## 3) Issues Found During Delivery and Resolution

### Issue A: `No host specified in URI /auth/login`
- Cause: relative path request without valid configured base URL.
- Resolution: base URL guards and API_BASE_URL-first flow.

### Issue B: Login timeout on physical Android device
- Cause: `10.0.2.2` works only for emulator; not valid on real device.
- Resolution: use LAN host in dart-define, e.g.:
  - `flutter run --dart-define=API_BASE_URL=http://192.168.1.167:8000`

### Issue C: UI crash (`Navigator ... _history.isNotEmpty`)
- Cause: interceptor forced route reset for all 401 responses, including login failure.
- Resolution: skip forced logout logic for auth endpoints and add re-entry guard.

### Issue D: Backend 500 on register/login path
- Cause: passlib+bcrypt compatibility/runtime mismatch in container.
- Resolution: pin `bcrypt==4.0.1` and update password hashing configuration.

## 4) Validation Results

### 4.1 API validation
- `/health` responds successfully.
- `/auth/register` successful after backend dependency fix.
- `/auth/login` successful with valid credentials.
- `/auth/logout` reachable and returns expected response contract.

### 4.2 Account/role validation in DB
Current users verified in PostgreSQL:
- `admin@school.edu` (admin)
- `teacher@school.edu` (teacher)
- `student@school.edu` (student)

Teacher and student test accounts were added and login-tested.

### 4.3 App behavior validation
- App can login using new backend token response format.
- Logout path clears local auth state and syncs with backend logout endpoint.
- Login 401 no longer causes navigator assertion crash.

## 5) Security and Repo Hygiene Notes

- Env files are ignored before push (`.env` patterns updated in `.gitignore`).
- No `.env` file was included in pushed commit.

## 6) Remaining Risks / Tech Debt

- Legacy naming (`odoo`) still exists in parts of local storage APIs and should be refactored for clarity.
- Branch currently contains broad file changes beyond auth-focused files (including environment artifacts); recommended to clean in a follow-up if strict PR scope is required.

## 7) Recommended Next Steps

1. Add backend seed script for `admin/teacher/student` default users.
2. Add automated tests for `register/login/me/logout` endpoints.
3. Refactor legacy local keys/services to neutral naming (`auth`/`api` instead of `odoo`).
4. Create a cleanup commit to remove accidental environment/vendor files from version control if needed.

## 8) Runbook (for QA)

- Start backend and DB.
- Run app with LAN URL:
  - `flutter run --dart-define=API_BASE_URL=http://<LAN_IP>:8000`
- Test login with:
  - admin: `admin@school.edu` / `admin123`
  - teacher: `teacher@school.edu` / `teacher123`
- Verify logout returns to login and protected calls require auth again.

## 9) Update [2026-03-21]: Refresh Token Flow & Logout Refactor

### 9.1 Backend Adjustments
- Expanded `LoginResponse` and `RegisterUserResponse` payload to securely include `refresh_token`.
- Refined the `/api/v1/users` (List Users) endpoint to properly eager-load user profiles (`student_profile` & `teacher_profile`) and safely extract IDs without risking `MissingGreenlet` lazy-load exceptions during runtime in async sessions.

### 9.2 Flutter Adjustments
- **Refresh Token Interceptor:** 
  - Upgraded `AuthInterceptor` logic using `QueuedInterceptor`.
  - The app now automatically catches **HTTP 401 Unauthorized** responses, locks the request queue, hits the `/api/v1/auth/refresh` endpoint with the saved `refreshToken`, updates local token storage upon success, and seamlessly retries the failed requests.
  - If the refresh token relies on an expired session or is invalid, the interceptor securely forces the app back to the login screen using `_forceLogout()`.
- **Logout Refactor:**
  - Consolidated local logout mechanics from `SettingCubit` into the strictly related `AccountCubit`.
  - Ensured both `access_token` and `refresh_token` are wiped thoroughly from `SharedPreferences` during all log out events (both user-initiated and interceptor-forced).
- **Local Service:**
  - Added new dedicated keys to inject and retrieve the refresh token locally.
