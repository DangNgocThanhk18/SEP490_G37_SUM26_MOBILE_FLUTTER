# ComiVerse Mobile

Android-first Flutter reader application for ComiVerse.

## Backend URL

The app uses the deployed Railway backend by default:

```text
https://sep490g37sum26java-production.up.railway.app/api
```

Therefore, this is enough for Android devices and emulators as long as they
have an internet connection:

```powershell
flutter run
```

Spring Boot does not need to be running locally. `API_BASE_URL` remains
available as a build-time override for local development or another deployed
environment. Do not commit a developer machine's LAN IP to the source code.

### Android Emulator

To deliberately use a Spring Boot instance running on the development
computer instead of Railway:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api
```

On an Android emulator, `10.0.2.2` points to the computer running Spring Boot.

### Physical Android Device

The phone and development computer must be on the same network. Replace the
example address with the computer's current IPv4 address:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8081/api
```

Spring Boot must listen on the LAN interface and the firewall must allow port
`8081`. `localhost` on a physical phone refers to the phone itself, not the
development computer.

### Flutter Web

The Railway backend currently allows the local web origin on port `5173`.
Run Flutter Web on that port:

```powershell
flutter run -d chrome --web-port=5173
```

To use local Spring Boot with Flutter Web, add the override:

```powershell
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8081/api
```

### Deployed Backend

Release builds also use Railway by default:

```powershell
flutter build apk --release
```

For another deployment, override it without changing tracked Dart files:

```powershell
flutter run --dart-define=API_BASE_URL=https://another-host.example/api
flutter build apk --release --dart-define=API_BASE_URL=https://another-host.example/api
```

## Push notifications

ComiVerse uses Firebase Cloud Messaging for account-targeted notifications
while the app is foregrounded, backgrounded, or terminated. The app remains
usable when Firebase is not configured, but push delivery is disabled until
both the mobile client and Spring Boot credentials are provisioned.

The Android and iOS native Firebase files are installed and connect normal
mobile runs to project `comiverse-cdb7b`:

```powershell
flutter run
```

For CI builds that intentionally omit the native Firebase files, copy
`firebase.local.example.json` to the ignored `firebase.local.json`, fill the
remaining API key, and launch with:

```powershell
flutter run --dart-define-from-file=firebase.local.json
```

The Firebase Android application must use package name
`com.example.comiverse_mobile`. For iOS, enable Push Notifications and
Background Modes/Remote notifications for bundle ID
`com.example.comiverseMobile`, then configure an APNs key in Firebase.

On Railway, configure these backend variables and redeploy Spring Boot:

```text
FIREBASE_PUSH_ENABLED=true
FIREBASE_PROJECT_ID=comiverse-cdb7b
FIREBASE_SERVICE_ACCOUNT_BASE64=<base64-service-account-json>
```

`FIREBASE_SERVICE_ACCOUNT_JSON` or `GOOGLE_APPLICATION_CREDENTIALS` can be
used instead of the Base64 value. Never commit a service-account JSON file or
its private key. Users must open the app once and allow notification permission
before the device can be registered to their account.

## Verification

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter build web --debug
```
