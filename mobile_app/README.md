# FORGEWATCH Android app

Flutter client for the existing Flask API. It shows live simulator readings and backend model outputs; it does not generate sensor data or classifications on the phone.

## API environments

`lib/config/api_config.dart` separates the environments:

- Production defaults to `https://kalyanfaultdetection.in` and requires HTTPS.
- Development uses `http://10.0.2.2:5000` for an Android emulator. A physical phone can use a reachable PC LAN address with `API_BASE_URL`.
- Android's development flavor allows HTTP for local testing. The production flavor disables cleartext traffic.

Start the local Flask server in the project root, then run this from `mobile_app`:

```powershell
flutter pub get
flutter run --flavor development --dart-define=APP_ENV=development
```

For a phone on the same Wi-Fi, replace the emulator address with the PC's LAN address:

```powershell
flutter run --flavor development --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://192.168.1.20:5000
```

Use a private LAN address that is reachable from your phone, and allow the Flask port through Windows Firewall. This development URL is not used by production builds.

## Screens and API data

The dashboard includes Overview, Live Monitoring, AI Fault Detection, Predictive Analysis, 3D Digital Twin, Simulation Control, Machine Comparison, Maintenance, Performance Analytics, Alerts, Notifications, Reports, and Profile. All values, ML classes, confidence, anomaly information, forecasts, remaining-useful-life estimates, alerts, maintenance, and analytics are fetched from Flask endpoints. Estimates retain the backend's simulated-data disclaimers.

Login and registration use `/api/auth/login` and `/api/auth/register`. Bearer tokens are stored with `flutter_secure_storage` and sent to authenticated API routes. API errors include offline, timeout, expired-session, and server responses. Admin/Engineer controls are hidden or disabled in the UI and still enforced by the API.

## Verify

```powershell
flutter analyze
flutter test
```

The development Android build can be installed locally with:

```powershell
flutter build apk --debug --flavor development --dart-define=APP_ENV=development
```

## Production APK

Do not build/distribute production until the HTTPS backend responds successfully at `https://kalyanfaultdetection.in/api/health`. Configure an Android upload key once and keep it backed up; loss of that key prevents upgrades under the same Android app identity.

From `mobile_app`, generate the key (Android Studio JBR's `keytool` asks interactively for passwords and certificate details):

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore android\app\forgewatch-release-key.jks -alias forgewatch -keyalg RSA -keysize 2048 -validity 10000
```

Set signing values in the current PowerShell session without echoing the passwords:

```powershell
$env:FORGEWATCH_KEYSTORE_PATH = (Resolve-Path android\app\forgewatch-release-key.jks).Path
$secureStore = Read-Host "Keystore password" -AsSecureString
$env:FORGEWATCH_KEYSTORE_PASSWORD = [Net.NetworkCredential]::new("", $secureStore).Password
$env:FORGEWATCH_KEY_ALIAS = "forgewatch"
$secureKey = Read-Host "Key password" -AsSecureString
$env:FORGEWATCH_KEY_PASSWORD = [Net.NetworkCredential]::new("", $secureKey).Password
```

After Render and custom-domain HTTPS are live:

```powershell
flutter build apk --release --flavor production --dart-define=APP_ENV=production
```

The APK is created under `build\app\outputs\flutter-apk\`. Signing secrets and keystore files are ignored by Git. Never commit them.
