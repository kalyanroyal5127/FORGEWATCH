# Machine Learning-Based Fault Detection and Prediction System

A software-only industrial machine monitoring demonstration. Python will generate simulated vibration, temperature, and current readings. No physical sensors, microcontrollers, or other hardware are required.

## Project structure

```text
Machine_Fault_Detection_AI/
├── backend/
│   ├── app.py             # Flask REST API and web static server
│   ├── database.py        # SQLite schema and persistence
│   ├── generate_dataset.py# Labelled synthetic CSV generator
│   ├── simulator.py       # Multi-machine simulated readings
│   ├── train_model.py     # Random Forest training/evaluation
│   ├── data/              # Generated CSV and SQLite database
│   └── models/            # Joblib model and JSON metrics
├── web/
│   ├── assets/
│   ├── css/
│   └── js/
├── mobile_app/
│   ├── android/           # Native Android wrapper
│   ├── lib/config/         # Development and production API settings
│   ├── lib/models/         # Backend response models
│   ├── lib/screens/        # Login and dashboard sections
│   ├── lib/services/       # Authenticated Flask client and exports
│   ├── lib/widgets/        # SCADA cards and charts
│   ├── lib/main.dart       # Flutter app entry point
│   └── pubspec.yaml
├── requirements.txt
└── README.md
```

## Windows setup

Open PowerShell in this project folder. The project already has a `venv` directory; these commands activate and use it without recreating it:

```powershell
.\venv\Scripts\Activate.ps1
python --version
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

If PowerShell blocks activation, use the venv interpreter directly for pip commands:

```powershell
.\venv\Scripts\python.exe -m pip install -r requirements.txt
```

Python 3.10 or newer is recommended. SQLite is included with Python. Flutter and Android Studio are required to build the Android client.

## Running the application

From the project root, start the backend (which serves the web dashboard and API) with:

```powershell
.\venv\Scripts\Activate.ps1
python -m backend.app
```

Open `http://127.0.0.1:5000/login` to sign in. After authentication, the dashboard is available at `http://127.0.0.1:5000/` or `/overview`. Signed-out visitors to either dashboard route are redirected to the login page. The API is available under `/api/`. All readings used for the demonstration are simulated.

Run the Android app in a second PowerShell terminal:

```powershell
cd mobile_app
flutter pub get
flutter run --flavor development --dart-define=APP_ENV=development
```

Development uses the emulator bridge `http://10.0.2.2:5000`. For a physical phone on the same LAN, pass `--dart-define=API_BASE_URL=http://<PC-LAN-IP>:5000` and permit that port through Windows Firewall. Production defaults to `https://kalyanfaultdetection.in`, uses Android cleartext traffic disabled, and persists bearer tokens with Android secure storage. Create the account at `/register` in the web app or in Flutter; both use the same backend user database.

Build a debug APK with:

```powershell
cd mobile_app
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --flavor development --dart-define=APP_ENV=development
```

The development APK is written under `mobile_app/build/app/outputs/flutter-apk/`. It uses the emulator API bridge and permits HTTP only in the development flavor.

Train the model explicitly with `python -m backend.train_model`. The app also trains a missing model on first startup. Export up to 5,000 latest records from `/api/reports.csv`.

## API reference

- `GET /api/health` — server and model status
- `GET /api/metrics` — holdout evaluation metrics and confusion matrix
- `GET /api/machines` — last saved reading per virtual machine
- `GET /api/snapshot` — generate, classify, and persist the next simulated readings
- `GET /api/history?machine_id=M-001&limit=100` — sensor history
- `GET /api/alerts` — fault alert history
- `GET /api/reports.csv` — CSV report download
- `POST /api/settings` — set `machines` and `fault_probability` (0 through 1)

## User accounts

Open `/register` to create the first operator account, then sign in at `/login`. Usernames must be 3–32 letters, numbers, or underscores; passwords must be at least four characters. Passwords are stored as Werkzeug password hashes in SQLite. Browser pages use a signed Flask session; Flutter receives a revocable bearer token and sends it with API requests. The Flutter login screen also supports account registration. Web sign-in uses standard username/current-password autofill hints and asks supporting browser password managers to save credentials after successful login; saved passwords remain in the browser password manager, not in the FORGEWATCH database. Sign out from the web sidebar or mobile app.

Password recovery is local because no email provider is configured. The `/forgot-password` page explains this and links to the safe terminal workflow. From the project root, run `python -m backend.reset_password USERNAME`; enter the new password at the hidden prompts. Resetting a password revokes that user's existing API tokens.

For local development only, Flask has a fallback session secret. Set a private `FORGEWATCH_SECRET_KEY` environment variable before exposing the app beyond the local demonstration. This project is not a hardened public identity service. Classifications identify current simulated conditions; the system does not forecast a failure time and has no real industrial validation.

### Phase 2: generate and inspect simulated data

The dataset generator uses only the Python standard library:

```powershell
python -m backend.generate_dataset --rows 4000 --seed 42
python -m backend.simulator
```

The generated labelled CSV is written to `backend/data/synthetic_sensor_readings.csv`. Use `--output path\to\file.csv` to choose another destination. The simulator prints one current reading per virtual machine as JSON. These synthetic labels support a classroom demonstration and do not represent industrial validation.

## Development phases

1. Project structure and Python environment
2. Synthetic sensor data and simulation
3. Random Forest training and evaluation
4. Flask API and SQLite persistence
5. Web dashboard
6. Flutter application
7. Integration and verification

Model classifications describe current simulated conditions. They are not validated predictions of real machine failures.

## Render deployment and custom domain

The repository includes `render.yaml` as a deployment template. If you already have a Render web service for this project, update that existing service's settings and keep using its current service hostname; do not create a second service. If you are creating the Render service for the first time, the Blueprint template defines the `forgewatch` service. Its build installs `requirements.txt` and trains the Random Forest and Isolation Forest artifacts from the checked-in synthetic CSV. The start command serves `backend.app:app` with Gunicorn on Render's assigned `$PORT`, and `/api/health` is the health check. Training in the build means the ignored `.joblib` files do not need to be committed and startup does not wait to train them. The Blueprint generates `FORGEWATCH_SECRET_KEY` and prompts for initial admin environment values. Never place production secrets in source control.

The Flask application continues to run locally on `http://127.0.0.1:5000`. The local `python -m backend.app` command reads `PORT` if set and otherwise uses port 5000. Render runs the same `backend.app:app` WSGI application through Gunicorn. Secure session cookies are enabled automatically in Render's environment and remain usable over local HTTP. Both `/` and `/overview` serve the existing dashboard after authentication; unauthenticated visitors are sent to `/login`.

### GitHub and Render deployment

1. Install [Git for Windows](https://git-scm.com/download/win), sign in to GitHub in your browser, then create a new **empty** GitHub repository. Do not initialize it with a README or license because this project already has those files.
2. Open PowerShell in the project root. Review `.gitignore` first; it excludes the `venv`, local `.env` files, SQLite database, local Flask session secret, Flutter SDK path, and model binaries. The synthetic CSV remains in Git so Render can train the models during its build.

```powershell
git init -b main
git add .
git status --short
git commit -m "Prepare FORGEWATCH for Render deployment"
git remote add origin https://github.com/<GITHUB_USERNAME>/<REPOSITORY_NAME>.git
git push -u origin main
```

Replace the two placeholders with your GitHub username and repository name. Complete GitHub authentication in the browser if prompted; do not put a GitHub password or token in the remote URL. Check the staged file list before committing, and never force-add `.env`, `backend/data/session_secret.key`, a SQLite database, or private credentials.

3. In Render, either connect the GitHub repository to the existing FORGEWATCH web service, or create a Blueprint from the repository if there is no service yet. For an existing service, do not create a duplicate. Use the repository root as the service root directory and branch `main`.
4. Confirm these service settings (also defined in `render.yaml`):

| Setting | Value |
| --- | --- |
| Runtime | Python |
| Build command | `pip install -r requirements.txt && python -m backend.train_model` |
| Start command | `gunicorn backend.app:app --bind 0.0.0.0:$PORT` |
| Health check path | `/api/health` |
| Python | `.python-version` selects Python 3.12 |
| `GUNICORN_CMD_ARGS` | `--preload --access-logfile -` |

The `GUNICORN_CMD_ARGS` setting replaces Render's default Gunicorn arguments so the start command binds only to Render's current `$PORT` instead of also requesting a fixed port.

5. Before the first production deploy, set these values in the service's **Environment** page. A new Blueprint asks for the two `sync: false` admin values; for an existing service, add them manually.

| Variable | Value |
| --- | --- |
| `FORGEWATCH_SECRET_KEY` | A long random secret; never commit it. The Blueprint generates one for a new service. |
| `FORGEWATCH_ADMIN_USERNAME` | Your initial admin username (3–32 letters, digits, or underscores). |
| `FORGEWATCH_ADMIN_PASSWORD` | A unique password of at least 4 characters. |

The app hashes this initial password with Werkzeug and creates the configured Admin if the database has no Admin yet. If an account with the configured username already exists, that account is promoted and its password is set from the environment secret. Keep these values in Render's environment settings. Set the admin values before first startup. Publicly registered accounts on Render receive the Operator role and cannot claim Admin through the registration form. On local Windows, the first account continues to receive Admin as before.

6. Deploy and wait for Render's deploy status to become **Live**. Open the service URL Render displays, then check `/api/health`, `/login`, and `/overview`. The service URL, such as `https://<service-name>.onrender.com`, is the shareable HTTPS link; `/` redirects signed-out visitors to the login page. Confirm a new account can sign in and that its role is shown in the dashboard before sharing the link.

### SQLite persistence

Render's default filesystem is ephemeral. The website and fresh database can run without extra storage, but registered accounts and sensor history may disappear after a restart or redeploy. To retain SQLite data, attach a persistent disk (available for paid web services) mounted at `/var/data`, then set `FORGEWATCH_DB_PATH=/var/data/machine_monitor.db` in the service environment. Without a disk, avoid treating the hosted SQLite database as durable. [Render persistent disk documentation](https://render.com/docs/disks).

On a Free Render service, the instance can spin down after inactivity and take about a minute to wake on the next request. A paid always-on service avoids this cold-start delay. [Render service FAQ](https://render.com/docs/faq).

### Preserve SQLite data on Render

Render's ordinary service filesystem is not persistent across service replacement or redeploy. If you want accounts, alerts, readings, and other SQLite records to survive deployments, attach a persistent disk to the web service in Render and set this environment variable to a file inside its mount directory:

```text
FORGEWATCH_DB_PATH=/var/data/machine_monitor.db
```

For example, mount the disk at `/var/data`. The application creates the database's parent directory and schema when it starts. Persistent disks may depend on your Render plan; check the current plan options before adding one. Without a persistent disk, the app still runs, but its SQLite data and generated session fallback file can be lost when the service is replaced. The Blueprint supplies a generated persistent Flask session key through `FORGEWATCH_SECRET_KEY`.

### Attach `kalyanfaultdetection.in`

These steps configure Render and your domain registrar manually; this repository does not purchase, register, or connect the domain.

1. Follow the GitHub and Render steps above, then open the existing web service and confirm its deploy succeeds. Keep the service's generated hostname, for example `forgewatch-xxxx.onrender.com`; use the exact hostname displayed for your service below.
2. In the service's **Settings → Custom Domains**, add `kalyanfaultdetection.in`. Render automatically includes the matching `www` hostname when you add a root domain. Save the change.
3. At the DNS provider for the domain, create these records. Delete conflicting `AAAA` records and any old `A`, `CNAME`, forwarding, or parking records for the same host names.

| Type | Host / Name | Value |
| --- | --- | --- |
| `A` | `@` | `216.24.57.1` |
| `CNAME` | `www` | `<your-service>.onrender.com` |

The `A` record above is Render's current documented IPv4 load-balancer address for apex/root domains when the provider does not support `ALIAS`, `ANAME`, or CNAME flattening. If the DNS provider supports one of those root alias record types, use an `ALIAS`/`ANAME` record for `@` pointing to the exact service hostname instead. For Cloudflare, use **CNAME** records for both `@` and `www`, each targeting the exact service hostname, with proxy status set to **DNS only** while Render verifies the domain and issues its certificate. Set Cloudflare SSL/TLS encryption mode to **Full**. After Render shows the certificate as valid, Cloudflare proxying is optional. For the `www` record, replace `<your-service>.onrender.com` with the exact hostname shown in the Render service; do not enter the placeholder literally. Do not create `AAAA` records for this Render setup.

4. Return to **Settings → Custom Domains** in Render and click **Verify** for the domain. DNS propagation can take time. Render's current platform documentation says it issues and renews the TLS certificate after verification and redirects HTTP traffic to HTTPS automatically. Then check `https://kalyanfaultdetection.in` and `https://www.kalyanfaultdetection.in`; when a root domain is configured Render routes the paired `www` hostname to it.
5. In the domain provider, keep the existing authoritative nameservers unless you intentionally plan to move DNS hosting. If the zone uses restrictive CAA records, allow Render's documented certificate authorities, Let's Encrypt (`letsencrypt.org`) and Google Trust Services (`pki.goog`).

Render's DNS targets and verification status in the service dashboard are authoritative. If Render displays a record specific to your service, use the value it shows. Do not disable the generated `onrender.com` address unless you specifically want to make the custom domain the only public hostname.

### Use the public API from Flutter

The app's production API default is `https://kalyanfaultdetection.in`. The custom domain must resolve to a live Render Flask service and `/api/health` must return `status: ok` before you distribute a production app. During this preparation the domain did not resolve, and `https://forgewatch.onrender.com/api/health` returned Render's `no-server` response; public API access has not been verified.

```powershell
cd mobile_app
Invoke-RestMethod https://kalyanfaultdetection.in/api/health
```

For a signed release APK, create and safely back up a private upload key. Never commit the generated key or its passwords. Run `keytool` from Android Studio's JBR and answer its password prompts:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore android\app\forgewatch-release-key.jks -alias forgewatch -keyalg RSA -keysize 2048 -validity 10000
$env:FORGEWATCH_KEYSTORE_PATH = (Resolve-Path android\app\forgewatch-release-key.jks).Path
$secureStore = Read-Host "Keystore password" -AsSecureString
$env:FORGEWATCH_KEYSTORE_PASSWORD = [Net.NetworkCredential]::new("", $secureStore).Password
$env:FORGEWATCH_KEY_ALIAS = "forgewatch"
$secureKey = Read-Host "Key password" -AsSecureString
$env:FORGEWATCH_KEY_PASSWORD = [Net.NetworkCredential]::new("", $secureKey).Password
flutter build apk --release --flavor production --dart-define=APP_ENV=production
```

The signed release output is `mobile_app/build/app/outputs/flutter-apk/app-production-release.apk`. Release builds fail if signing environment variables are missing. HTTPS is required in the production Android flavor. Website canonical metadata does not mean its domain is connected: deploy the Flask service, attach the custom domain in Render, configure DNS, and verify `/api/health` before considering the mobile app globally usable.
