import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';

/// Translates FirebaseAuthService results into the plain-Dart types that
/// UserProvider expects — no Firebase types leak beyond this file.
class FirebaseAuthRepository {
  FirebaseAuthRepository._();
  static final FirebaseAuthRepository instance = FirebaseAuthRepository._();

  final _service = FirebaseAuthService.instance;

  // ── Auth state ─────────────────────────────────────────────────────────────

  /// Emits [Map] whenever the Firebase auth state changes (on login/logout).
  /// Returns null when no user is signed in.
  Stream<Map<String, dynamic>?> get authStateChanges =>
      _service.authStateChanges.map(_userToMap);

  /// Returns a profile map for the current Firebase user, or null.
  Map<String, dynamic>? get currentUserMap => _userToMap(_service.currentUser);

  bool get isSignedIn => _service.currentUser != null;

  // ── Email / Password ───────────────────────────────────────────────────────

  /// Creates account and returns a profile map on success, or throws a
  /// descriptive [Exception].
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final user = await _service.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      return _userToMap(user)!;
    } on FirebaseAuthException catch (e) {
      throw Exception(FirebaseAuthService.friendlyMessage(e));
    }
  }

  /// Signs in and returns a profile map on success.
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _service.signInWithEmail(email: email, password: password);
      return _userToMap(user)!;
    } on FirebaseAuthException catch (e) {
      throw Exception(FirebaseAuthService.friendlyMessage(e));
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  /// Returns profile map after a Google sign-in, or null when user cancelled.
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      final user = await _service.signInWithGoogle();
      return _userToMap(user);
    } on FirebaseAuthException catch (e) {
      throw Exception(FirebaseAuthService.friendlyMessage(e));
    } catch (e) {
      throw Exception('Google sign-in failed. Please try again.');
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> signOut() => _service.signOut();

  /// Fresh Firebase ID token for the backend exchange, or null if signed out.
  Future<String?> getIdToken() async {
    final user = _service.currentUser;
    return user?.getIdToken(true);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Map<String, dynamic>? _userToMap(User? user) {
    if (user == null) return null;
    return {
      'id': user.uid,
      'full_name': user.displayName ?? 'User',
      'email': user.email ?? '',
      'role_occupation': '',
      'primary_objective': '',
      'experience_level': 'Intermediate',
      'target_industry': '',
      'feedback_style': 'Encouraging & Constructive',
      'is_guest': false,
      // Theme is owned by local preference in UserProvider — never force light.
    };
  }
}
