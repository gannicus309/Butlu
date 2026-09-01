import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  runApp(const ProviderScope(child: ButluApp()));
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
