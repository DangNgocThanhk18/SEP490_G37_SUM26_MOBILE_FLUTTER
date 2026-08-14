# ComiVerse Mobile

Android-first Flutter reader application for ComiVerse.

## Backend URL

The app uses the deployed Railway backend by default:

```text
https://sep490g37sum26java-production-0ff1.up.railway.app/api
```

Therefore, this is enough for Android devices and emulators as long as they
have an internet connection:

```powershell
flutter run
```

Spring Boot does not need to be running locally. `API_BASE_URL` remains
available as a build-time override for local development or another deployed
environment. Do not commit a developer machine's LAN IP to the source code.

`API_BASE_URL` is compiled into the application. After a Railway domain
changes, rebuild and reinstall the APK/IPA; an already installed build keeps
the previous backend URL.

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

## Screen capture protection

Comic Reader screens enable native screen-capture protection by default. In
debug and profile builds, Profile > App Settings includes a local switch so a
team member can temporarily disable protection while presenting through
`scrcpy`.

A normal release build always hides this switch and forces protection on, even
if the same device previously stored an off value from a demo build:

```powershell
flutter build apk --release
```

When the presentation specifically needs release-mode performance, create a
demo-only APK with the control explicitly enabled:

```powershell
flutter build apk --release --dart-define=COMIVERSE_DEMO_CAPTURE_CONTROL=true
```

Do not use `COMIVERSE_DEMO_CAPTURE_CONTROL=true` for the production artifact.

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

## Launcher icon and native splash

Mobile branding is derived from
`../ComiVerse_FE/src/components/common/LogoIcon.jsx`. The square two-slash mark
is used for Android/iOS launcher icons and Android 12+, while the full wordmark
is used on the earlier Android and iOS launch screens.

Regenerate the native resources after changing a branding source asset:

```powershell
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Android launchers cache icons. Uninstall the previous build or remove and add
the launcher shortcut again when visually verifying an icon change.

## Secure Android offline chapters

Offline chapter packages are Android-only, encrypted page-by-page, stored in
the app-private support directory, and opened only after a server-signed
7-day license is validated. Build with the backend's pinned Ed25519 public key
(Base64 raw 32-byte key or Base64 X.509 SubjectPublicKeyInfo):

```powershell
flutter run -d <android-device> `
  --dart-define=API_BASE_URL=https://<backend>/api `
  --dart-define=OFFLINE_LICENSE_ED25519_PUBLIC_KEY=<base64-public-key> `
  --dart-define=OFFLINE_LICENSE_SIGNING_KEY_ID=offline-ed25519-v1
```

The public verification key is not a secret, but it must come from the trusted
release configuration—not from an offline-license response. Missing or invalid
pinning disables downloads and fails closed. The backend must configure the
matching Ed25519 private key and the `comiverse-api` / `comiverse-android`
issuer/audience contract.

Release APKs must use a real signing key. Create `android/key.properties`
(ignored by Git) locally or in CI:

```properties
storeFile=C:/secure/comiverse-upload.jks
storePassword=<secret>
keyAlias=comiverse
keyPassword=<secret>
```

Then build with the same public-key define:

```powershell
flutter build apk --release `
  --dart-define=OFFLINE_LICENSE_ED25519_PUBLIC_KEY=<base64-public-key> `
  --dart-define=OFFLINE_LICENSE_SIGNING_KEY_ID=offline-ed25519-v1
```

The release build intentionally fails if `android/key.properties` is absent;
debug/profile builds remain usable with local HTTP backends. Release traffic is
HTTPS-only. This DRM is defense in depth and cannot guarantee protection on a
rooted, hooked, or modified device.
