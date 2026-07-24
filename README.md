# ComiVerse Mobile

Android-first Flutter reader application for ComiVerse.

## Backend URL

The backend address is configured at build/run time with `API_BASE_URL`. Do not
commit a developer machine's LAN IP to the source code.

### Android Emulator

The default URL is already configured for the Android Studio emulator:

```powershell
flutter run
```

It resolves to `http://10.0.2.2:8081/api`. On an Android emulator,
`10.0.2.2` points to the computer running Spring Boot.

### Physical Android Device

The phone and development computer must be on the same network. Replace the
example address with the computer's current IPv4 address:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8081/api
```

Spring Boot must listen on the LAN interface and the firewall must allow port
`8081`. `localhost` on a physical phone refers to the phone itself, not the
development computer.

### Deployed Backend

Use the public HTTPS API URL for a cloud build:

```powershell
flutter run --dart-define=API_BASE_URL=https://api.comiverse.example/api
flutter build apk --release --dart-define=API_BASE_URL=https://api.comiverse.example/api
```

Each developer can use their own URL without changing tracked Dart files.

## Verification

```powershell
flutter analyze
flutter test
flutter build apk --debug
```
