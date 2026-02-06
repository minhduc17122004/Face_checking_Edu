# Security Configuration Guide

## ⚠️ Important: This project has been cleaned of sensitive information

All sensitive keys, credentials, and configuration values have been removed for security purposes. You need to configure these values before running the project.

## Required Configuration Files

### 1. Android Signing Configuration
Create a file `android/key.properties` with the following content:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=path/to/your/keystore.jks
```

### 2. Android Local Properties
Update `android/local.properties` with your SDK paths:
```properties
sdk.dir=YOUR_ANDROID_SDK_PATH
flutter.sdk=YOUR_FLUTTER_SDK_PATH
flutter.buildMode=debug
flutter.versionName=1.2.2
flutter.versionCode=44
```

### 3. Build Configuration
The file `lib/configs/build_config.dart` needs to be configured with:
- Base URL for API endpoints
- Base Image URL
- App Store URLs
- Kakao API Key (if using)

### 4. Package Name
The package name has been changed to a generic one: `com.example.face_time_keeping`
- Update this in `android/app/build.gradle`
- Update package declarations in Kotlin files

## Files Protected by .gitignore

The following sensitive files are now excluded from version control:
- `android/key.properties` - Signing keys
- `android/local.properties` - Local SDK paths
- `*.keystore`, `*.jks` - Keystore files
- `google-services.json` - Firebase config
- `GoogleService-Info.plist` - iOS Firebase config
- `.env`, `.env.local` - Environment variables
- `*.pem` - Certificate files

## Security Best Practices

1. **Never commit sensitive information** to version control
2. **Use environment variables** for API keys and secrets
3. **Generate new keys** if old keys were accidentally exposed
4. **Keep keystore files secure** and backed up safely
5. **Use different keys** for development and production
6. **Rotate credentials regularly**

## Setup Instructions

1. Clone the repository
2. Create the required configuration files (as listed above)
3. Configure your own API endpoints and keys
4. Generate a new Android signing key:
   ```bash
   keytool -genkey -v -keystore release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release
   ```
5. Run `flutter pub get`
6. Build and run the project

## Contact

For access to the original configuration values, contact the project maintainer.

---
**Last Updated:** 2026-02-01
