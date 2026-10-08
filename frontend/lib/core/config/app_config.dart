import 'package:flutter/foundation.dart';

/// Application-wide configuration constants.
///
/// Production / release builds MUST be given an HTTPS backend:
///   flutter build appbundle --release --dart-define=API_BASE_URL=https://api.yourdomain.com
/// (validated at startup by [validate]).
///
/// In debug/development, pass `--dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:8000`
/// when running on a physical phone, or omit it to automatically use the
/// Android emulator host address (10.0.2.2) or localhost for iOS/desktop.
class AppConfig {
  AppConfig._();

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Explicit `--dart-define=API_BASE_URL=...` wins.
  /// In debug/profile without `--dart-define`, automatically resolves:
  /// - Android Emulator: http://10.0.2.2:8000
  /// - iOS Simulator / Web / Desktop: http://localhost:8000
  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Call once at startup. Throws in release if the backend URL is missing or not HTTPS,
  /// so a misconfigured build fails on first launch instead of shipping with a dev URL.
  static void validate() {
    if (!kReleaseMode) return;
    if (_envBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not set. Build with --dart-define=API_BASE_URL=https://...',
      );
    }
    if (!_envBaseUrl.startsWith('https://')) {
      throw StateError(
        'API_BASE_URL must use https:// in release builds (got $_envBaseUrl).',
      );
    }
  }

  // ── Polling configuration for results / processing screens ─────────────────
  static const Duration resultsPollInitialInterval = Duration(seconds: 2);
  static const Duration resultsPollMaxInterval = Duration(seconds: 10);
  static const Duration resultsPollTimeout = Duration(minutes: 3);
  static const int resultsPollMaxAttempts = 45; // ~3 minutes with backoff
}
