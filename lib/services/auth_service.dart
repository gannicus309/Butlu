import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps Firebase Auth + Google Sign-In (v7's initialize/authenticate API).
///
/// Google Sign-In on Flutter Web needs an explicit OAuth Web client ID (native
/// platforms read it from GoogleService-Info.plist/google-services.json
/// instead) -- see [_webClientId].
///
/// Web has a second, more fundamental difference: [GoogleSignIn.authenticate]
/// throws `UnimplementedError` there -- Google requires a button rendered by
/// their own SDK (`google_sign_in_web`'s `renderButton()`) rather than an
/// app-triggered popup. Both paths end up completing sign-in the same way
/// though: via the `authenticationEvents` stream, listened to once here, so
/// callers never need to know which platform they're on.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  bool _initialized = false;

  /// From Firebase Console -> Authentication -> Sign-in method -> Google ->
  /// Web SDK configuration -> Web client ID. Only used on kIsWeb.
  static const String _webClientId =
      '552503667814-ldojrnhek3r2fcdf2m1prr09sj9feok1.apps.googleusercontent.com';

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  /// False on web -- callers must render `google_sign_in_web`'s
  /// `renderButton()` there instead of a custom button calling
  /// [signInWithGoogle].
  bool get supportsExplicitSignIn => _googleSignIn.supportsAuthenticate();

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize(clientId: kIsWeb ? _webClientId : null);
    _googleSignIn.authenticationEvents.listen(_onGoogleAuthEvent);
    _initialized = true;
    // Silently resume a previous session if one exists (e.g. page refresh).
    unawaited(_googleSignIn.attemptLightweightAuthentication());
  }

  Future<void> _onGoogleAuthEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      await _completeFirebaseSignIn(event.user);
    }
  }

  Future<void> _completeFirebaseSignIn(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null) return;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _firebaseAuth.signInWithCredential(credential);
  }

  /// Native/mobile explicit sign-in. On web, render
  /// `google_sign_in_web`'s `renderButton()` instead -- see
  /// [supportsExplicitSignIn].
  Future<void> signInWithGoogle() async {
    await ensureInitialized();
    await _googleSignIn.authenticate();
    // Firebase sign-in completes asynchronously via the authenticationEvents
    // listener registered in ensureInitialized(); authStateChanges reflects
    // it once that finishes.
  }

  /// Anonymous Firebase sign-in for development builds -- see `kDevSignIn`.
  Future<void> signInForDevelopment() async {
    await _firebaseAuth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }
}
