# TechZone — Local Run Guide

The project has two parts:

- `Backend/` — Django + Django REST Framework API (SQLite)
- `frontend/` — Flutter app (web / Android)

Run the backend first, then the frontend in a separate terminal.
All commands below are for **PowerShell on Windows**.

---

## 1. Backend (Django API)

```powershell
cd E:\tech_zone\Backend

# Activate the virtual environment (venv is already in the repo)
.\venv\Scripts\Activate.ps1

# Install dependencies (first time, or on a new machine)
pip install -r requirements.txt

# Apply migrations
python manage.py migrate

# Create an admin user (optional, only if you need the admin panel)
python manage.py createsuperuser

# Start the dev server
python manage.py runserver
```

| What | URL |
| --- | --- |
| API root | http://127.0.0.1:8000/api/v1 |
| Admin panel | http://127.0.0.1:8000/admin |

**If `Activate.ps1` fails with an execution-policy error**, run once in the same terminal:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

## 2. Frontend (Flutter)

Open a **new terminal** and keep the Django server running.

```powershell
cd E:\tech_zone\frontend

flutter pub get
flutter devices          # check which devices are available

flutter run -d chrome    # run on web
```

---

## 3. API base URL per target

The default base URL is defined in `frontend/lib/core/config/app_config.dart`
(`API_BASE_URL`, default `http://127.0.0.1:8000`). It is read with
`String.fromEnvironment`, so it is overridden at launch with `--dart-define`.

### Chrome / Windows desktop

The default works as-is:

```powershell
flutter run -d chrome
```

### Android emulator

Inside the emulator `127.0.0.1` means the emulator itself, so the host machine
must be addressed as `10.0.2.2`:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### Physical phone on the same Wi-Fi

Find the PC's LAN IP with `ipconfig`, let Django listen on all interfaces, and
point the app at that IP:

```powershell
# Terminal 1 (Backend)
python manage.py runserver 0.0.0.0:8000

# Terminal 2 (frontend) — replace with your own IP
flutter run --dart-define=API_BASE_URL=http://192.168.0.X:8000
```

### Production / deployed build

```powershell
flutter build web --dart-define=API_BASE_URL=https://api.example.com
```

---

## Notes

- `config/settings.py` already sets `ALLOWED_HOSTS = ["*"]` and
  `CORS_ALLOW_ALL_ORIGINS = True`, so no extra CORS setup is needed for local
  development.
- Email uses the console backend in development — verification links and OTP
  mails are printed in the Django terminal, not actually sent.
- Uploaded media is served from `Backend/media/` while `DEBUG = True`.
- Git workflow for the team (branching, commit, push) is in `Guideline/start`.
