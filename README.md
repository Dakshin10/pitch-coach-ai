# 🎯 Pitch Coach

A modern Flutter app for practicing public speaking, pitch presentations, and interview skills — with real-time feedback, analytics, and a polished light/dark design system.

---

## 🚀 Features

- **Interactive Onboarding**: Brand-forward intro with animated sound waves and guest / login entry points.
- **Home Dashboard**: Practice modes, weekly progress stats, recent sessions, and quick lesson chips.
- **Interview & Pitch Practice**: Timed practice with audio recording and AI-backed feedback (via backend).
- **Performance Analytics**: Charts and metrics for clarity, pace, confidence, and filler words.
- **History & Progress**: Session history, trends, achievements, and skill breakdowns.
- **Profile & Settings**: Editable profile, reminders, and preferences.
- **Light / Dark Theme**: Animated theme toggle on onboarding, home, profile, and edit profile. Preference is stored locally and survives restarts.
- **Web (Chrome) Support**: Startup is hardened for Flutter web (notifications skipped; Firebase failures no longer blank the screen).

---

## 🛠️ Tech Stack

### Frontend (Flutter)
- Flutter / Dart (`^3.10.0`)
- `go_router`, `provider`, `dio`, `fl_chart`
- `flutter_secure_storage` (tokens + local theme preference)
- `record`, `audioplayers`, `video_player`, `flutter_local_notifications`
- `google_fonts` (Plus Jakarta Sans), Firebase Auth / Google Sign-In

### Backend (Python FastAPI)
- FastAPI + Uvicorn
- SQLAlchemy / SQLite
- Groq API (`GROQ_API_KEY`) for transcription and feedback

---

## 📁 Project Architecture

```
pitch-coach/
├── backend/                    # Python FastAPI backend
│   ├── auth/                   # Auth routes & JWT
│   ├── sessions/               # Audio upload & evaluation
│   ├── users/                  # Profile & stats
│   ├── main.py
│   ├── requirements.txt
│   ├── .env.example            # Template — copy to .env (never commit secrets)
│   └── start.bat
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── theme/              # Colors, typography, light/dark ThemeData
│   │   ├── widgets/            # Atmosphere, glass surfaces, theme toggle, nav
│   │   ├── providers/          # User / stats / session results
│   │   ├── repositories/
│   │   └── utils/              # Conditional dart:io helpers for web
│   └── features/
│       ├── onboarding/
│       ├── home/
│       ├── interview/
│       ├── history/
│       ├── progress/
│       ├── profile/            # Profile + edit profile (theme-aware)
│       ├── auth/
│       ├── learn/
│       └── results/
```

---

## 🏁 How to Run

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.10.0+)
- [Python 3.10+](https://www.python.org/)
- Chrome (for web), Android emulator, iOS simulator, or a physical device

---

### Step 1: Backend

#### Quick start (venv already set up)
```powershell
cd backend
start.bat
```

#### First-time setup
```powershell
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
# Edit .env and set GROQ_API_KEY=...
start.bat
```

API: `http://localhost:8000` — docs at `http://localhost:8000/docs`

---

### Step 2: Flutter app

From the project root:

```powershell
flutter pub get
```

**Chrome / web**
```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

**Android emulator**
```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

**Physical device (same Wi‑Fi)** — use your PC LAN IP from `ipconfig`:
```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
```

**Desktop / localhost**
```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

Without `--dart-define`, guest / local mock mode is used (no backend calls).

Use the sun/moon button to switch light and dark themes. The choice is kept on device.

---

## 🎨 Recent UI / UX notes

- Atmospheric gradient backgrounds with soft aurora motion in dark mode
- Glass-style cards and theme-aware text/surfaces across home, profile, history, and progress
- Edit Profile screen follows the active theme
- Theme preference no longer resets after a failed backend sync

---

## ⚙️ Windows Build Troubleshooting

If the project drive differs from the Pub Cache drive, Kotlin incremental compilation may fail. In `android/gradle.properties`:

```properties
kotlin.incremental=false
kotlin.incremental.usePreciseJavaTracking=false
```

---

## 🧪 Command Reference

### 1. Flutter Commands

#### Setup & Clean
```powershell
# Get dependencies
flutter pub get

# Clean build artifacts & rebuild cache
flutter clean
flutter pub get

# Check for outdated packages
flutter pub outdated
```

#### Devices & Emulators
```powershell
# List all available devices (Connected Android, Web, Windows)
flutter devices

# List available Android emulators
flutter emulators

# Launch a specific Android emulator
flutter emulators --launch Pixel_6a
```

#### Running the App
```powershell
# Run on Windows Desktop
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8000

# Run on Web (Chrome)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000

# Run on Android Emulator (10.0.2.2 points to host machine localhost)
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Run on Physical Device (replace with your PC's LAN IP from ipconfig)
flutter run -d <device-id> --dart-define=API_BASE_URL=http://192.168.1.50:8000
```

#### Analysis & Testing
```powershell
# Analyze code for warnings and lint errors
flutter analyze

# Run unit and widget tests
flutter test
```

#### Build Release Artifacts
```powershell
# Build Android APK (Debug / Release)
flutter build apk --debug
flutter build apk --release

# Build Android App Bundle (.aab)
flutter build appbundle

# Build Web distribution
flutter build web

# Build Windows Desktop executable
flutter build windows
```

---

### 2. Backend (FastAPI) Commands

#### Setup (from `backend/` directory)
```powershell
cd backend

# Create Python virtual environment
python -m venv venv

# Activate venv (Windows PowerShell)
.\venv\Scripts\activate

# Install required dependencies
pip install -r requirements.txt

# Create environment config from template
copy .env.example .env
```

#### Running the Server
```powershell
# Option 1: Using startup batch script (Windows)
.\start.bat

# Option 2: Running directly via python module (Avoids Windows script execution policy issues)
.\venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
---

## 📄 License

This project is created for educational and development purposes.
