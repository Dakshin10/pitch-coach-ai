# 🎯 Pitch Coach

A modern, intuitive Flutter mobile application designed to help users prepare, practice, and master their public speaking, pitch presentations, and job interview skills with real-time feedback and detailed performance analytics.

---

## 🚀 Features

- **🎬 Interactive Onboarding**: Seamless introduction guiding users through core features and personalized goal setting.
- **📊 Home Dashboard**: Quick overview of recent activity, upcoming practice sessions, and recommended pitch modules.
- **🎙️ Real-Time Interview & Pitch Practice**: Dedicated practice room equipped with timers, prompt triggers, and interactive feedback.
- **📈 Advanced Performance Analytics**: Detailed charts and broken-down metrics (powered by `fl_chart`) covering clarity, pace, confidence, and filler word usage.
- **🗓️ History & Session Tracking**: Revisit past practice sessions, review recorded performance stats, and track improvements over time.
- **📈 Progress Metrics**: Track growth trends, personal milestones, and long-term pitch performance evolution.
- **👤 Profile & Settings**: Custom user settings, preference toggles, and performance summary.
- **🎨 Custom Design System**: Supports both Light and Dark modes with custom typography (`Google Fonts`), smooth route transitions, and responsive layouts.

---

## 🛠️ Tech Stack & Dependencies

- **Framework**: [Flutter](https://flutter.dev/) (Dart SDK `^3.10.7`)
- **Navigation & Routing**: [`go_router`](https://pub.dev/packages/go_router)
- **Data Visualization**: [`fl_chart`](https://pub.dev/packages/fl_chart)
- **State Management**: [`provider`](https://pub.dev/packages/provider)
- **Typography & Icons**: [`google_fonts`](https://pub.dev/packages/google_fonts), [`flutter_svg`](https://pub.dev/packages/flutter_svg), [`cupertino_icons`](https://pub.dev/packages/cupertino_icons)

---

## 📁 Project Architecture

```
lib/
├── main.dart                   # Application entry point
├── core/                       # Shared app-wide core modules
│   ├── router/                 # AppRouter & GoRouter configurations
│   └── theme/                  # AppTheme (Light & Dark theme definitions)
└── features/                   # Feature-first modular architecture
    ├── demo/                   # Design system demo & component showcase
    ├── history/                # Session history & past logs
    ├── home/                   # Main dashboard screen
    ├── interview/              # Interactive pitch/interview practice screen
    ├── onboarding/             # Intro and onboarding flow
    ├── profile/                # User profile & settings screen
    ├── progress/               # Progress tracking & growth metrics
    └── results/                # Post-session result breakdown & analytics charts
```

---

## 🏁 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.10.7 or later)
- [Dart SDK](https://dart.dev/get-started)
- Android Studio / Xcode / VS Code with Flutter extension installed
- An active Android Emulator, iOS Simulator, or connected physical device

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Dakshin10/pitch-coach.git
   cd pitch-coach
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   flutter run
   ```

---

## 🧪 Development Commands

- **Run code analysis:**
  ```bash
  flutter analyze
  ```

- **Run tests:**
  ```bash
  flutter test
  ```

- **Build release APK (Android):**
  ```bash
  flutter build apk --release
  ```

---

## 📄 License

This project is created for educational and development purposes.
