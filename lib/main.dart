import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/dev_mode.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/screens/family_setup_screen.dart';
import 'features/auth/screens/sign_in_screen.dart';
import 'features/calendar/providers/calendar_selection_provider.dart';
import 'firebase_options.dart';
import 'shared/widgets/butlu_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const ButluRoot(),
    ),
  );
}

Widget _wrapPlain(Widget home) =>
    MaterialApp(title: 'Butlu', theme: butluTheme, home: home);

/// Decides which of sign-in / family setup / the real app shell to show.
/// Exactly one MaterialApp(-router) is ever mounted at a time -- [ButluApp]
/// is `MaterialApp.router` on its own, so it's swapped in wholesale rather
/// than nested inside another MaterialApp.
class ButluRoot extends ConsumerWidget {
  const ButluRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        if (user != null) return const _FamilyGate();
        if (!kDevSignIn) return _wrapPlain(const SignInScreen());
        // Dev builds skip Google: sign in anonymously, and authStateProvider
        // moves on to _FamilyGate once that lands.
        return ref
            .watch(devSignInProvider)
            .when(
              data: (_) => _wrapPlain(const _LoadingScreen()),
              loading: () => _wrapPlain(const _LoadingScreen()),
              error: (error, stackTrace) =>
                  _wrapPlain(_ErrorScreen(error: error)),
            );
      },
      loading: () => _wrapPlain(const _LoadingScreen()),
      error: (error, stackTrace) => _wrapPlain(_ErrorScreen(error: error)),
    );
  }
}

class _FamilyGate extends ConsumerWidget {
  const _FamilyGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(familyStatusProvider);
    return status.when(
      data: (status) => switch (status) {
        FamilyStatusMember(familyId: final familyId) => ProviderScope(
          overrides: [familyIdProvider.overrideWithValue(familyId)],
          child: const ButluApp(),
        ),
        _ => _wrapPlain(FamilySetupScreen(status: status)),
      },
      loading: () => _wrapPlain(const _LoadingScreen()),
      error: (error, stackTrace) => _wrapPlain(_ErrorScreen(error: error)),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: ButluLogo(pulse: true)));
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Something went wrong: $error')));
  }
}

class ButluApp extends StatelessWidget {
  const ButluApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Butlu',
      theme: butluTheme,
      routerConfig: appRouter,
    );
  }
}
