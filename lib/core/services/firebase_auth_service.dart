import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps FirebaseAuth and GoogleSignIn so the rest of the codebase never
/// imports Firebase SDKs directly. All auth operations return [User?] or
/// throw a [FirebaseAuthException] / [FirebaseSignInException] that the
/// repository translates into human-readable messages.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Auth-state stream ──────────────────────────────────────────────────────

  /// Emits the current [User] whenever auth state changes (login / logout).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns the currently signed-in Firebase user (null if none).
  User? get currentUser => _auth.currentUser;

  // ── Email / Password ───────────────────────────────────────────────────────

  /// Creates a new account with [email] and [password].
  /// Optionally updates the display name to [displayName].
  Future<User> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    if (displayName != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
      await user.reload();
    }
    return _auth.currentUser!;
  }

  /// Signs in with [email] and [password].
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  /// Triggers the Google OAuth flow and signs the resulting credential into
  /// Firebase.  Returns null if the user cancelled the flow.
  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  /// Signs out from both Firebase and Google (if Google was used).
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Converts a [FirebaseAuthException] code to a user-friendly English message.
  static String friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Contact support.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method for that email.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
