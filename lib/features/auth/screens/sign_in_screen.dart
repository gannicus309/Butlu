import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/google_sign_in_button.dart';
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

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Butlu', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Your shared family calendar',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
            ],
            init.when(
              data: (_) => _buildSignInButton(),
              loading: () => const CircularProgressIndicator(),
              error: (e, st) =>
                  Text('Sign-in unavailable: $e', style: const TextStyle(color: Colors.redAccent)),
            ),
          ],
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
