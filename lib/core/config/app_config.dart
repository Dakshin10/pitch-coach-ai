/// Application-wide configuration constants.
///
/// ── HOW TO SWITCH TARGETS ─────────────────────────────────────────────────
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
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _usePhysicalDevice ? _physicalUrl : _emulatorUrl,
  );

  // ── Polling interval for results screen (waits for is_analyzed = true) ────
  static const Duration resultsPollInterval = Duration(seconds: 2);
  static const int resultsPollMaxAttempts = 30; // ~60 seconds timeout
}
