// `google_sign_in_web`'s `renderButton()` uses web-only APIs that don't
// compile on native platforms, so it's behind this conditional import
// (mirroring the pattern in google_sign_in's own example app).
export 'google_sign_in_button_stub.dart'
    if (dart.library.js_util) 'google_sign_in_button_web.dart';
