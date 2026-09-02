import 'package:flutter/widgets.dart';

/// Never actually called -- `AuthService.supportsExplicitSignIn` is true on
/// every platform except web, so callers branch away from this before it
/// would run.
Widget renderGoogleSignInButton() {
  throw StateError('renderGoogleSignInButton() should only be called on web.');
}
