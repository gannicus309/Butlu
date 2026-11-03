import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/google_sign_in_button.dart';
import '../../../shared/widgets/butlu_logo.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../providers/auth_providers.dart';

/// Initializes Google Sign-In once, ahead of the button being shown -- both
/// [AuthService.supportsExplicitSignIn] and the web render-button path need
/// it to have run first.
final _googleSignInInitProvider = FutureProvider<void>((ref) {
  return ref.watch(authServiceProvider).ensureInitialized();
});

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final init = ref.watch(_googleSignInInitProvider);

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.45),
            radius: 1.1,
            // Pre-blended to an opaque colour: a translucent stop fades through
            // murky grey on its way to the opaque surface colour.
            colors: [
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.16),
                scheme.surface,
              ),
              scheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FadeSlideIn(child: ButluLogo(size: 96)),
                const SizedBox(height: 28),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: Text(
                    'Butlu',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    'Your shared family calendar',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 40),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 320),
                  child: init.when(
                    data: (_) => _buildSignInButton(),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, st) => Text(
                      'Sign-in unavailable: $e',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    final authService = ref.read(authServiceProvider);
    if (!authService.supportsExplicitSignIn) {
      // Web: Google requires their own rendered button, not an app-triggered
      // popup -- authService.authStateChanges picks up the result once the
      // user completes sign-in through it.
      return renderGoogleSignInButton();
    }
    return FilledButton.icon(
      onPressed: _busy ? null : _signIn,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.login),
      label: const Text('Sign in with Google'),
    );
  }
}
