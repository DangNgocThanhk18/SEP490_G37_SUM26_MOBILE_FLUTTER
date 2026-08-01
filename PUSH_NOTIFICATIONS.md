# ComiVerse mobile push setup

The application code handles foreground, background, terminated, token refresh,
account switching, logout, and notification-tap deep links. The native Firebase
client files contain public app identifiers and are kept with the mobile project;
Firebase Admin/service-account credentials are secrets and must never be
committed.

GitHub secret scanning intentionally ignores only the two native client config
paths through `.github/secret_scanning.yml`. Their auto-created Android/iOS API
keys must remain restricted to Firebase-related APIs in Google Cloud. This
exception never applies to an Admin SDK service-account JSON, private key, or
the Railway `FIREBASE_SERVICE_ACCOUNT_BASE64` value.

## Firebase client

Create Android and iOS applications in the same Firebase project using the
package identifiers currently configured by the project:

- Firebase project: `comiverse-cdb7b` (`1096631184302`)
- Android: `com.example.comiverse_mobile`
- iOS: `com.example.comiverseMobile`

Both native apps are registered in Firebase Console. `google-services.json`
is installed in `android/app`, and `GoogleService-Info.plist` is installed in
the iOS Runner target. Their public app IDs are also recorded in
`firebase.local.example.json` for CI environments that prefer dart-defines.

Normal Android/iOS development runs now use the native files automatically:

```powershell
flutter run
```

CI may instead pass the public Firebase application values explicitly:

```powershell
flutter run -d <device> `
  --dart-define=FIREBASE_API_KEY=<api-key> `
  --dart-define=FIREBASE_PROJECT_ID=<project-id> `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<sender-id> `
  --dart-define=FIREBASE_ANDROID_APP_ID=<android-app-id> `
  --dart-define=FIREBASE_IOS_APP_ID=<ios-app-id>
```

Only the app ID for the target platform is required when using dart-defines.

For iOS, upload an APNs authentication key in Firebase Console and use an Apple
provisioning profile with the Push Notifications entitlement. Test remote push
on a physical iOS device. For Android emulators, use an image with Google Play
services and accept the Android 13+ notification permission prompt.

## Railway backend

Enable the Firebase Cloud Messaging HTTP v1 API, then configure Railway:

- `FIREBASE_PUSH_ENABLED=true`
- `FIREBASE_PROJECT_ID=comiverse-cdb7b`
- `FIREBASE_SERVICE_ACCOUNT_BASE64=<base64 service-account JSON>`

`FIREBASE_SERVICE_ACCOUNT_JSON` or `GOOGLE_APPLICATION_CREDENTIALS` are also
supported. The service-account JSON is a secret and must never be committed.
With `FIREBASE_PUSH_ENABLED=false` (the default), database and WebSocket
notifications continue to work and the application starts normally.

## Delivery checklist

- Foreground: a branded ComiVerse in-app banner appears and the unread badge is
  refreshed; the OS does not show a duplicate banner.
- Background/terminated: Android/iOS displays the high-priority OS notification.
- Tap: forum, comic, chapter, and legacy comment links open their safe in-app
  destination; the notification is marked read when possible.
- Login/session restore: the current Firebase installation is associated with
  that account. Token refresh updates the association.
- Logout: the server association is removed and the local FCM token is deleted,
  including the safe local invalidation path when the network is offline.

An Android app that the user explicitly force-stops, or an iOS app the user
swipes away, must be opened again before the platform resumes remote delivery.
