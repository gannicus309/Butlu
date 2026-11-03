/// Set `"BUTLU_DEV_SIGN_IN": true` in dart_define.json to skip Google sign-in
/// while developing: the app signs in anonymously and uses its own separate
/// dev family. Needs Anonymous sign-in enabled in the Firebase console and the
/// matching rule in firestore.rules. Leave it out (false) for real use.
const bool kDevSignIn = bool.fromEnvironment('BUTLU_DEV_SIGN_IN');
