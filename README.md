# Expense Tracker Mobile

Flutter mobile client for the Expense Tracker project. The app uses `Riverpod` for state management, `Dio` for API calls, and secure storage for auth/session data.

## Features

- Login flow with persisted session
- Dashboard with analytics and recent transactions
- History screen with category filters and chart
- Add and edit expense forms
- Profile screen with theme mode toggle
- Light, dark, and system theme modes

## Stack

- `Flutter`
- `flutter_riverpod`
- `dio`
- `flutter_secure_storage`
- `fl_chart`
- `intl`

## Requirements

- Flutter SDK
- Dart SDK
- A running Expense Tracker backend API
- Android emulator, iOS simulator, or physical device

## Backend Connection

The app resolves API base URL like this:

- Default production URL: `https://expense-tracker-backend-47s3.vercel.app/api/v1`

You can override it at build time with:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

## Local Setup

1. Move into the mobile folder:

```bash
cd mobile
```

2. Install dependencies:

```bash
flutter pub get
```

3. Start the backend API first.

4. Run the app:

```bash
flutter run
```

## Common Commands

- `flutter pub get`: install packages
- `flutter run`: run the app
- `flutter analyze`: run static analysis
- `dart format lib`: format source files

## Production Release

Android production release is prepared in this repo.

- Release guide: [RELEASE.md](/Users/passiongeekmm-002/Documents/TestingCodeX/mobile/RELEASE.md)
- Release signing config: `mobile/android/key.properties`
- Recommended build:
- Smallest Play Store upload:

```bash
cd mobile
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=API_BASE_URL=https://expense-tracker-backend-47s3.vercel.app/api/v1
```

For a smaller directly installable APK, use split-per-ABI:

```bash
cd mobile
flutter build apk --release --split-per-abi \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=API_BASE_URL=https://expense-tracker-backend-47s3.vercel.app/api/v1
```

## Project Structure

- `lib/main.dart`: app bootstrap, auth gate, theme wiring
- `lib/core/`: shared navigation, theme, network, and storage code
- `lib/features/auth/`: login screen
- `lib/features/expenses/`: dashboard, add/edit expense flow, providers
- `lib/features/history/`: history list and analytics
- `lib/features/navigation/`: bottom navigation shell
- `lib/features/profile/`: profile and appearance settings

## Theme Support

The app includes:

- `Light mode`
- `Dark mode`
- `System mode`

Users can switch theme mode from the Profile screen.

## Troubleshooting

### App cannot connect to backend

Check that:

- the emulator/device can reach the configured base URL
- your `API_BASE_URL` override matches the correct host for the device

### Android emulator cannot reach localhost

Use:

```text
http://10.0.2.2:3000/api/v1
```

instead of `127.0.0.1`.
