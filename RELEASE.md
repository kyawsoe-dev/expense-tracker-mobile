# Mobile Release Guide

This project is currently prepared for Android production releases.

## 1. Configure production API

The app already supports a production API URL through `--dart-define`.

Example:

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=API_BASE_URL=https://expense-tracker-backend-47s3.vercel.app/api/v1
```

## 2. Create an Android upload keystore

Run:

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

Place the generated file in:

```text
mobile/android/upload-keystore.jks
```

## 3. Create `key.properties`

Copy:

```text
mobile/android/key.properties.example
```

to:

```text
mobile/android/key.properties
```

Then fill in your real keystore values.

## 4. Build release bundle

Recommended for Play Store:

```bash
cd mobile
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=API_BASE_URL=https://expense-tracker-backend-47s3.vercel.app/api/v1
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## 5. Build smaller release APK

If you need a directly installable APK, use split-per-ABI to keep each file smaller:

```bash
cd mobile
flutter build apk --release --split-per-abi \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=API_BASE_URL=https://expense-tracker-backend-47s3.vercel.app/api/v1
```

Output files:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

## 6. Build release APK

For direct install/testing:

```bash
cd mobile
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=API_BASE_URL=https://expense-tracker-backend-47s3.vercel.app/api/v1
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 7. Important notes

- Release signing uses `mobile/android/key.properties` when present.
- If `key.properties` is missing, Gradle falls back to the debug key only for local testing.
- The Android production application ID is:

```text
com.kyawsoe.expensetracker
```

- Increase the version in `pubspec.yaml` before each store release.

Example:

```yaml
version: 1.0.1+2
```
