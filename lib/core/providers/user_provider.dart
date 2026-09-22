import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';

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
        memberSince: '',
      );
}

/// UserProvider — wires all auth operations to the real API.
/// Public interface (getters/method signatures) is unchanged so screens recompile.
class UserProvider extends ChangeNotifier {
  final _auth = AuthRepository.instance;

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

  UserProfile get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── App startup: try to restore session ──────────────────────────────────

  Future<bool> tryRestoreSession() async {
    if (!await _auth.hasStoredTokens) return false;
    // Try to fetch /me — if it fails the token is expired
    final userData = await _auth.getMe();
    if (userData == null) {
      await _auth.logout();
      return false;
    }
    _user = UserProfile.fromJson(userData);
    _isLoggedIn = true;
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
      _user = UserProfile.fromJson(userData);
      _isLoggedIn = true;
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
      _user = UserProfile.fromJson(userData);
      _isLoggedIn = true;
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

  Future<bool> loginAsGuest() async {
    _setLoading(true);
    try {
      final userData = await _auth.loginAsGuest();
      _user = UserProfile.fromJson(userData);
      _isLoggedIn = true;
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
    if (fields.isNotEmpty) {
      try {
        final updated = await _auth.updateMe(fields);
        _user = UserProfile.fromJson(updated);
        notifyListeners();
      } catch (_) {
        // If API fails, local values remain — not critical
      }
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _auth.logout();
    _isLoggedIn = false;
    _user = UserProfile(
      name: 'Guest',
      email: '',
      role: '',
      targetGoal: '',
      experienceLevel: 'Beginner',
      targetIndustry: '',
      feedbackTone: 'Encouraging & Constructive',
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
