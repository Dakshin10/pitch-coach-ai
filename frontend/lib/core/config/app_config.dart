import 'package:flutter/foundation.dart';

/// Application-wide configuration constants.
///
/// Release builds MUST be given an HTTPS backend:
///   flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com
/// (validated at startup by [validate]).
///
/// ── HOW TO SWITCH TARGETS (debug only) ────────────────────────────────────
///   1. Android emulator on this PC:  use [_emulatorUrl]   (already default)
///   2. Physical device on same WiFi: use [_physicalUrl]   (fill in your LAN IP)
///   3. Run `ipconfig` in cmd to find your machine's IPv4 address.
///   4. Ensure Windows Firewall allows inbound connections on port 8000.
///      (Control Panel → Windows Defender Firewall → Allow an app → add uvicorn / port 8000)
class AppConfig {
  AppConfig._();

  // ── Backend URL (flip the comment to switch targets) ──────────────────────

  // Target 1: Android emulator on the same PC
  static const String _emulatorUrl = 'http://10.0.2.2:8000';

  // Target 2: Physical device — replace with your machine's LAN IP
  // Run `ipconfig` and look for "IPv4 Address" under your Wi-Fi adapter.
  static const String _physicalUrl = 'http://192.168.1.100:8000'; // ← change me

  /// Active backend URL.  Change [_usePhysicalDevice] to true when testing
  /// on a real device.
  static const bool _usePhysicalDevice = false;
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Explicit --dart-define wins. Debug/profile fall back to the dev URLs above;
  /// release never falls back (see [validate]).
  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return _usePhysicalDevice ? _physicalUrl : _emulatorUrl;
  }

  /// Call once at startup. Throws in release if the backend URL is missing or not HTTPS,
  /// so a misconfigured build fails on the first launch instead of shipping with a dev URL.
  static void validate() {
    if (!kReleaseMode) return;
    if (_envBaseUrl.isEmpty) {
      throw StateError('API_BASE_URL is not set. Build with --dart-define=API_BASE_URL=https://...');
    }
    if (!_envBaseUrl.startsWith('https://')) {
      throw StateError('API_BASE_URL must use https:// in release builds (got $_envBaseUrl).');
    }
  }

  // ── Polling interval for results screen (waits for is_analyzed = true) ────
  static const Duration resultsPollInterval = Duration(seconds: 2);
  static const int resultsPollMaxAttempts = 30; // ~60 seconds timeout
}
