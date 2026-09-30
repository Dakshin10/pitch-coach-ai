import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../repositories/auth_repository.dart';
import '../repositories/firebase_auth_repository.dart';

enum AuthState { loading, unauthenticated, guest, authenticated, error }

/// UserProfile — keeps the same shape as before so all screens compile unchanged.
class UserProfile {
  String id;
  String name;
  String email;
  String role;
  String targetGoal;
  String experienceLevel;
  String targetIndustry;
  String feedbackTone;
  bool isGuest;
  bool darkMode;

  // Stats are now fetched separately via StatsProvider; keep as fallback defaults
  int sessionsCompleted;
  double avgScore;
  String memberSince;

  UserProfile({
    this.id = '',
    required this.name,
    required this.email,
    required this.role,
    required this.targetGoal,
    required this.experienceLevel,
    required this.targetIndustry,
    required this.feedbackTone,
    this.isGuest = false,
    this.darkMode = false,
    this.sessionsCompleted = 0,
    this.avgScore = 0.0,
    this.memberSince = '',
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'PC';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Build from API /me response JSON.
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String? ?? '',
        name: j['full_name'] as String? ?? 'User',
        email: j['email'] as String? ?? '',
        role: j['role_occupation'] as String? ?? '',
        targetGoal: j['primary_objective'] as String? ?? '',
        experienceLevel: j['experience_level'] as String? ?? 'Intermediate',
        targetIndustry: j['target_industry'] as String? ?? '',
        feedbackTone: j['feedback_style'] as String? ?? 'Encouraging & Constructive',
        isGuest: j['is_guest'] as bool? ?? false,
        darkMode: j['dark_mode'] as bool? ?? false,
        memberSince: '',
      );
}

/// UserProvider — wires all auth operations to the real API **and** Firebase.
/// Public interface (getters/method signatures) is unchanged so screens recompile.
class UserProvider extends ChangeNotifier {
  final _auth = AuthRepository.instance;
  final _firebaseAuth = FirebaseAuthRepository.instance;
  static const _storage = FlutterSecureStorage();
  static const _darkModeKey = 'pitch_coach_dark_mode';

  UserProfile _user = UserProfile(
    name: 'Guest',
    email: '',
    role: '',
    targetGoal: '',
    experienceLevel: 'Beginner',
    targetIndustry: '',
    feedbackTone: 'Encouraging & Constructive',
  );

  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;
  bool _localThemeLoaded = false;

  UserProfile get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isGuest => _isLoggedIn && _user.isGuest;
  AuthState get authState => _isLoading
      ? AuthState.loading
      : _error != null
          ? AuthState.error
          : !_isLoggedIn
              ? AuthState.unauthenticated
              : _user.isGuest ? AuthState.guest : AuthState.authenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ThemeMode get themeMode => _user.darkMode ? ThemeMode.dark : ThemeMode.light;

  /// Apply API/Firebase profile without clobbering the locally chosen theme.
  void _adoptUser(Map<String, dynamic> data) {
    final keptDark = _user.darkMode;
    _user = UserProfile.fromJson(data);
    _user.darkMode = keptDark;
    _isLoggedIn = true;
  }

  Future<void> _loadLocalTheme() async {
    if (_localThemeLoaded) return;
    try {
      final raw = await _storage.read(key: _darkModeKey);
      if (raw != null) {
        _user.darkMode = raw == 'true';
        notifyListeners();
      }
    } catch (_) {
      // Storage unavailable — keep in-memory default.
    } finally {
      _localThemeLoaded = true;
    }
  }

  Future<void> _persistLocalTheme(bool enabled) async {
    try {
      await _storage.write(key: _darkModeKey, value: enabled.toString());
    } catch (_) {
      // Non-fatal — theme still works for this session.
    }
  }

  // ── App startup: try to restore session ──────────────────────────────────

  /// Restores an existing Firebase session (persisted by the Firebase SDK).
  /// Call this from main() so the app skips onboarding on restart.
  Future<bool> tryRestoreFirebaseSession() async {
    final userData = _firebaseAuth.currentUserMap;
    if (userData == null) return false;
    _adoptUser(userData);
    notifyListeners();
    return true;
  }

  Future<bool> tryRestoreSession() async {
    await _loadLocalTheme();
    // First try Firebase (preferred flow going forward)
    if (await tryRestoreFirebaseSession()) return true;
    // Fallback: legacy JWT token from the REST API
    if (!await _auth.hasStoredTokens) return false;
    // Try to fetch /me — if it fails the token is expired
    final userData = await _auth.getMe();
    if (userData == null) {
      await _auth.logout();
      return false;
    }
    _adoptUser(userData);
    notifyListeners();
    return true;
  }

  // ── Login / Signup ────────────────────────────────────────────────────────

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final userData = await _auth.signup(
        email: email,
        password: password,
        fullName: name,
      );
      _adoptUser(userData);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    try {
      final userData = await _auth.login(email: email, password: password);
      _adoptUser(userData);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Firebase auth methods ─────────────────────────────────────────────────

  /// Sign up via Firebase email/password.
  Future<bool> firebaseSignUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final userData = await _firebaseAuth.signUpWithEmail(
        email: email,
        password: password,
        displayName: name,
      );
      _adoptUser(userData);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign in via Firebase email/password.
  Future<bool> firebaseLogin({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final userData = await _firebaseAuth.signInWithEmail(
        email: email,
        password: password,
      );
      _adoptUser(userData);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign in via Google using Firebase.
  /// Returns true on success, false if the user cancelled, throws on error.
  Future<bool> firebaseSignInWithGoogle() async {
    _setLoading(true);
    try {
      final userData = await _firebaseAuth.signInWithGoogle();
      if (userData == null) {
        // User cancelled the Google flow
        return false;
      }
      _adoptUser(userData);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Signs out from Firebase (and Google if used). Also clears legacy tokens.
  Future<void> firebaseLogout() async {
    await _firebaseAuth.signOut();
    await _auth.logout(); // also clear any legacy JWT tokens
    final keptDark = _user.darkMode;
    _isLoggedIn = false;
    _user = UserProfile(
      name: 'Guest',
      email: '',
      role: '',
      targetGoal: '',
      experienceLevel: 'Beginner',
      targetIndustry: '',
      feedbackTone: 'Encouraging & Constructive',
      darkMode: keptDark,
    );
    _error = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> loginAsGuest() async {
    // Guest is a local demo identity. It has no token and never calls protected APIs.
    await _auth.logout();
    final keptDark = _user.darkMode;
    _user = UserProfile(
      id: 'demo-guest', name: 'Guest', email: '', role: 'Student',
      targetGoal: 'Build confidence', experienceLevel: 'Beginner',
      targetIndustry: '', feedbackTone: 'Encouraging & Constructive',
      isGuest: true, sessionsCompleted: 5, avgScore: 82,
      darkMode: keptDark,
    );
    _isLoggedIn = true;
    _error = null;
    notifyListeners();
    return true;
  }

  // ── Profile update ────────────────────────────────────────────────────────

  Future<void> updateProfile({
    String? name,
    String? email,
    String? role,
    String? targetGoal,
    String? experienceLevel,
    String? targetIndustry,
    String? feedbackTone,
  }) async {
    final fields = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) {
      fields['full_name'] = name.trim();
      _user.name = name.trim();
    }
    if (role != null && role.trim().isNotEmpty) {
      fields['role_occupation'] = role.trim();
      _user.role = role.trim();
    }
    if (targetGoal != null && targetGoal.trim().isNotEmpty) {
      fields['primary_objective'] = targetGoal.trim();
      _user.targetGoal = targetGoal.trim();
    }
    if (experienceLevel != null && experienceLevel.trim().isNotEmpty) {
      fields['experience_level'] = experienceLevel.trim();
      _user.experienceLevel = experienceLevel.trim();
    }
    if (targetIndustry != null && targetIndustry.trim().isNotEmpty) {
      fields['target_industry'] = targetIndustry.trim();
      _user.targetIndustry = targetIndustry.trim();
    }
    if (feedbackTone != null && feedbackTone.trim().isNotEmpty) {
      fields['feedback_style'] = feedbackTone.trim();
      _user.feedbackTone = feedbackTone.trim();
    }

    notifyListeners(); // optimistic UI update
    if (_user.isGuest || !_isLoggedIn) return;
    if (!await _auth.hasStoredTokens) return;
    if (fields.isNotEmpty) {
      try {
        final updated = await _auth.updateMe(fields);
        _adoptUser(updated);
        notifyListeners();
      } catch (_) {
        // If API fails, local values remain — not critical
      }
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    _user.darkMode = enabled;
    notifyListeners();
    await _persistLocalTheme(enabled);

    // Best-effort backend sync only for authenticated REST users.
    // Never revert local theme if sync fails (onboarding / Firebase / offline).
    if (!_isLoggedIn || _user.isGuest) return;
    if (!await _auth.hasStoredTokens) return;
    try {
      await _auth.updateMe({'dark_mode': enabled});
    } catch (_) {
      // Keep the local preference — backend sync is optional.
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _auth.logout();
    final keptDark = _user.darkMode;
    _isLoggedIn = false;
    _user = UserProfile(
      name: 'Guest',
      email: '',
      role: '',
      targetGoal: '',
      experienceLevel: 'Beginner',
      targetIndustry: '',
      feedbackTone: 'Encouraging & Constructive',
      darkMode: keptDark,
    );
    _error = null;
    notifyListeners();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  String _extractErrorMessage(Object e) {
    if (e is DioException) {
      final detail = (e.response?.data as Map?)?['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        return 'Please check the highlighted registration details.';
      }
      if (e.response?.statusCode == 409) return 'An account with this email already exists.';
      if (e.response?.statusCode == 400) return 'Please check your details and try again.';
      if (e.response?.statusCode != null) return 'The server could not complete your request. Please try again.';
    }
    final str = e.toString();
    // Dio DioException message often contains the backend detail string
    if (str.contains('detail')) {
      final match = RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(str);
      if (match != null) return match.group(1)!;
    }
    if (str.contains('SocketException') || str.contains('connection')) {
      return 'Cannot connect to server. Make sure the backend is running.';
    }
    return 'Something went wrong. Please try again.';
  }
}
