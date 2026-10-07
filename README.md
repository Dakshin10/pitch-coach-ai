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
- **Slide Coach (Multimodal Deck Vision)**:
  - **Upload & Vision Extraction**: Upload a pitch deck (PDF) to scan charts, KPIs, diagrams, and text density with Groq Vision.
  - **AI Talking Points & Scripts**: Tailored talking points, transition hooks, and word-for-word scripts matching your exact time budget.
  - **Slide-Aligned Rehearsal**: Landscape-friendly rehearsal recorder that splits audio per slide, tracks WPM, counts fillers (including Hinglish/Tamil), checks talking points coverage, and provides coach agent feedback.
  - **Audience Q&A Prep**: Generates 5-8 tough audience-specific questions with reasoning, transcribes your answers, and grades clarity, directness, evidence, and confidence.
- **Light / Dark Theme**: Animated theme toggle on onboarding, home, profile, and edit profile. Preference is stored locally and survives restarts.
- **Web (Chrome) Support**: Startup is hardened for Flutter web (notifications skipped; Firebase failures no longer blank the screen).

---

## 🛠️ Tech Stack

### Frontend (Flutter)
- Flutter / Dart (`^3.10.0`)
- `go_router`, `provider`, `dio`, `fl_chart`, `file_picker`
- `flutter_secure_storage` (tokens + local theme preference)
- `record`, `audioplayers`, `video_player`, `flutter_local_notifications`
- `google_fonts` (Plus Jakarta Sans), Firebase Auth / Google Sign-In

### Backend (Python FastAPI)
- FastAPI + Uvicorn
- Firebase Admin SDK (Firestore & Storage)
- PyMuPDF (`pymupdf`) & Pillow for PDF-to-image rendering
- Groq Vision (`qwen/qwen3.8-27b`) for multimodal diagram & visual extraction
- Groq Text LLM (`openai/gpt-oss-120b`) for coaching synthesis and evaluation
- Groq Whisper (`whisper-large-v3-turbo`) for word-level speech transcription

---

## 📁 Project Architecture

```
pitch-coach/
├── backend/                    # Python FastAPI backend
│   ├── auth/                   # Auth routes & JWT
│   ├── sessions/               # Audio upload & evaluation
│   ├── slides/                 # Multimodal Slide Coach engine (Vision, PyMuPDF, Q&A)
│   ├── users/                  # Profile & stats
│   ├── tests/                  # Unit tests (unittest)
│   ├── main.py
│   ├── requirements.txt
│   ├── .env.example            # Template — copy to .env (never commit secrets)
│   └── start.bat
└── frontend/                   # Flutter application
    ├── lib/
    │   ├── main.dart
    │   ├── core/
    │   │   ├── theme/          # Colors, typography, light/dark ThemeData
    │   │   ├── widgets/        # Atmosphere, glass surfaces, theme toggle, nav
    │   │   ├── providers/      # User, stats, session, SlideCoachProvider
    │   │   ├── repositories/   # ApiClient, slide coach repository
    │   │   └── utils/          # Conditional dart:io helpers for web
    │   └── features/
    │       ├── onboarding/
    │       ├── home/
    │       ├── interview/
    │       ├── slide_coach/    # Deck upload, vision review, rehearsal, Q&A prep
    │       ├── history/
    │       ├── progress/
    │       ├── profile/
    │       ├── auth/
    │       ├── learn/
    │       └── results/
    ├── test/                   # Flutter unit & widget tests
    └── pubspec.yaml
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

### Step 2: Frontend (Flutter app)

Navigate to the `frontend/` directory:

```powershell
cd frontend
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

### 1. Flutter Commands (from `frontend/` directory)

#### Setup & Clean
```powershell
cd frontend

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

## 📊 Slide Coach AI Documentation

### Architecture & Three-Stage Pipeline
1. **Stage A: Render (PyMuPDF)**: Validates `%PDF` magic bytes, ensures length is between 1 and 30 pages (under 25MB), and renders crisp JPEGs at max 1024px width (quality 70).
2. **Stage B: Vision Extraction (Groq Vision)**: Sends slides in concurrent batches of $\le 5$ images to `qwen/qwen3.8-27b` to extract titles, main messages, diagrams, trend directions, and readability issues in strict JSON mode with Pydantic validation.
3. **Stage C: Coaching Synthesis (Groq LLM)**: Synthesizes slide visual descriptions and speaker constraints into a cohesive narrative arc, calculates slide duration budgets matching `time_limit_seconds` ($\pm 5\%$), and creates talking points and transition hooks with `openai/gpt-oss-120b`.
4. **Rehearsal Mode**: Records audio while the presenter swipes slides, transcribes with word-level Groq Whisper timestamps, splits transcript per slide, computes WPM and filler counts (including Tamil/Hinglish fillers: *um, uh, like, actually, basically, so, ah, enna, paa*), evaluates talking points coverage, and invokes the agentic coach.
5. **Q&A Mode**: Generates 5–8 tough, audience-tailored questions with underlying rationale and grades spoken responses on clarity, directness, evidence, and confidence.

### Slide Coach Environment Variables (`backend/.env`)
| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `GROQ_VISION_MODEL` | `qwen/qwen3.8-27b` | Multimodal model for slide diagram and visual analysis |
| `GROQ_TEXT_MODEL` | `openai/gpt-oss-120b` | Flagship text LLM with JSON mode for speech coaching |
| `GROQ_WHISPER_MODEL` | `whisper-large-v3-turbo` | Speech-to-text model with word-level timestamps |
| `SLIDE_DECK_DIR` | `./slide_decks` | Local disk folder for rendered slide JPEGs |
| `SLIDE_DECK_TTL_DAYS` | `7` | Retention window before confidential deck files are cleaned |

### Slide Coach API Endpoints
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/api/slides/upload` | Multipart upload (PDF + audience + time_limit + goal) with SHA-256 deduplication |
| `GET` | `/api/slides/{deck_id}/status` | Polls pipeline stage (`rendering`, `reading_slides`, `writing_coaching`) and progress |
| `GET` | `/api/slides/{deck_id}` | Returns full structured coaching result (story arc, score, slides, talking points) |
| `GET` | `/api/slides/{deck_id}/slides/{n}/image` | Serves rendered JPEG image for slide $n$ |
| `PATCH`| `/api/slides/{deck_id}/slides/{n}` | Saves user edits to talking points or script (debounced) |
| `POST` | `/api/slides/{deck_id}/rehearse` | Submits audio + slide swipe timestamps for per-slide rehearsal metrics |
| `POST` | `/api/slides/{deck_id}/qa/questions` | Generates 5–8 audience-specific presentation questions |
| `POST` | `/api/slides/{deck_id}/qa/answer` | Grades recorded answer with Whisper + Coach scoring |
| `POST` | `/api/slides/cleanup` | Cleans up decks older than configured TTL |
| `DELETE`| `/api/slides/{deck_id}` | Deletes deck, Firestore document, and rendered assets |

### Testing
```powershell
# Run Backend Unit Tests (10/10 tests)
cd backend
.\venv\Scripts\python.exe -m unittest tests/test_slides_pipeline.py

# Run Flutter Static Analysis
cd ..
flutter analyze
```

---

## 📄 License

This project is created for educational and development purposes.
