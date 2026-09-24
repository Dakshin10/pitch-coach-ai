# 🎯 Pitch Coach

A modern, intuitive Flutter mobile application designed to help users prepare, practice, and master their public speaking, pitch presentations, and job interview skills with real-time feedback and detailed performance analytics.

---

## 🚀 Features

- **🎬 Interactive Onboarding**: Seamless introduction guiding users through core features and personalized goal setting.
- **📊 Home Dashboard**: Quick overview of recent activity, upcoming practice sessions, and recommended pitch modules.
- **🎙️ Real-Time Interview & Pitch Practice**: Dedicated practice room equipped with timers, prompt triggers, audio recording, and interactive feedback.
- **📈 Advanced Performance Analytics**: Detailed charts and broken-down metrics (powered by `fl_chart`) covering clarity, pace, confidence, and filler word usage.
- **🗓️ History & Session Tracking**: Revisit past practice sessions, review recorded performance stats, and track improvements over time.
- **📈 Progress Metrics**: Track growth trends, personal milestones, and long-term pitch performance evolution.
- **👤 Profile & Settings**: Custom user settings, preference toggles, and performance summary.
- **🎨 Custom Design System**: Supports both Light and Dark modes with custom typography (`Google Fonts`), smooth route transitions, and responsive layouts.

---

## 🛠️ Tech Stack & Dependencies

### Frontend (Flutter)
- **Framework**: [Flutter](https://flutter.dev/) (Dart SDK `^3.10.0`)
- **Navigation & Routing**: [`go_router`](https://pub.dev/packages/go_router)
- **Data Visualization**: [`fl_chart`](https://pub.dev/packages/fl_chart)
- **State Management**: [`provider`](https://pub.dev/packages/provider)
- **HTTP Client**: [`dio`](https://pub.dev/packages/dio)
- **Secure Storage**: [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
- **Audio Recording & Playback**: [`record`](https://pub.dev/packages/record), [`audioplayers`](https://pub.dev/packages/audioplayers)
- **Video & Notifications**: [`video_player`](https://pub.dev/packages/video_player), [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications)
- **Typography & Icons**: [`google_fonts`](https://pub.dev/packages/google_fonts), [`flutter_svg`](https://pub.dev/packages/flutter_svg), [`cupertino_icons`](https://pub.dev/packages/cupertino_icons)

### Backend (Python FastAPI)
- **Framework**: FastAPI (Uvicorn server)
- **Database**: SQLite / SQLAlchemy
- **AI Integration**: Groq API (`GROQ_API_KEY`) for pitch evaluation & feedback

---

## 📁 Project Architecture

```
pitch-coach/
├── backend/                    # Python FastAPI backend server
│   ├── auth/                   # Authentication routes & JWT logic
│   ├── sessions/               # Audio upload & evaluation endpoints
│   ├── users/                  # User profile & stats endpoints
│   ├── main.py                 # FastAPI application entry point
│   ├── requirements.txt        # Python dependencies
│   └── start.bat               # Windows startup script
├── lib/                        # Flutter frontend application
│   ├── main.dart               # Application entry point
│   ├── core/                   # Shared app-wide core modules (router, theme, services)
│   └── features/               # Feature-first modular architecture
│       ├── demo/               # Design system demo & component showcase
│       ├── history/            # Session history & past logs
│       ├── home/               # Main dashboard screen
│       ├── interview/          # Interactive pitch/interview practice screen
│       ├── onboarding/         # Intro and onboarding flow
│       ├── profile/            # User profile & settings screen
│       ├── progress/           # Progress tracking & growth metrics
│       └── results/            # Post-session result breakdown & analytics charts
```

---

## 🏁 How to Run

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.10.0 or later)
- [Python 3.10+](https://www.python.org/) (for running the backend)
- Android Studio / VS Code with Flutter extension
- Android Emulator, iOS Simulator, or connected physical device

---

### Step 1: Start the Backend (FastAPI)

#### ⚡ Quick Start (If environment is already set up)
```powershell
cd backend
start.bat
```
*or directly with python:*
```powershell
cd backend
venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

#### 🛠️ First-Time Setup & Run
```powershell
# 1. Navigate to backend directory
cd backend

# 2. Create virtual environment
python -m venv venv

# 3. Activate virtual environment
venv\Scripts\activate

# 4. Install backend dependencies
pip install -r requirements.txt

# 5. Copy environment template & edit .env with your GROQ_API_KEY
copy .env.example .env

# 6. Start the FastAPI server
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The backend server will run on `http://localhost:8000`.


---

### Step 2: Run the Flutter App

1. **Navigate back to the project root:**
   ```powershell
   cd ..
   ```

2. **Get Flutter dependencies:**
   ```powershell
   flutter pub get
   ```

3. **Launch the Flutter app with your backend URL:**

   - **Android Emulator**:
     ```powershell
     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
     ```

   - **Physical Device (Same Wi-Fi network)**:
     Find your computer's LAN IP (e.g. `192.168.1.50`) using `ipconfig`, then run:
     ```powershell
     flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
     ```

   - **Desktop / Web / Localhost**:
     ```powershell
     flutter run --dart-define=API_BASE_URL=http://localhost:8000
     ```

   - **Guest Mode (Offline / Local Mock Mode)**:
     If you run standard `flutter run` without `--dart-define`, Guest Mode is enabled, operating locally without calling the backend API.

---

## ⚙️ Windows Build Troubleshooting

If building on Windows where the project directory drive differs from the Pub Cache drive (e.g., project on `D:` and pub cache on `C:`), Kotlin incremental compilation may throw a cross-root `IllegalArgumentException`.

Ensure `android/gradle.properties` contains:
```properties
kotlin.incremental=false
kotlin.incremental.usePreciseJavaTracking=false
```

---

## 🧪 Development Commands

- **Run code analysis:**
  ```bash
  flutter analyze
  ```

- **Run unit tests:**
  ```bash
  flutter test
  ```

- **Build debug APK:**
  ```bash
  flutter build apk --debug
  ```

- **Build release APK (Android):**
  ```bash
  flutter build apk --release
  ```

---

## 📄 License

This project is created for educational and development purposes.
