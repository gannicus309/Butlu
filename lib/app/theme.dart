import 'package:flutter/material.dart';

final ColorScheme _scheme =
    ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A84FF),
      brightness: Brightness.dark,
    ).copyWith(
      // Deeper, slightly blue-tinted surfaces than the seed's defaults, so cards
      // lift off the background the way grouped lists do in iOS dark mode.
      surface: const Color(0xFF0E1116),
      surfaceContainerLow: const Color(0xFF151A21),
      surfaceContainer: const Color(0xFF1A2029),
      surfaceContainerHigh: const Color(0xFF212833),
    );

/// Dark theme by default, blue accent matching iOS system blue -- the
/// Calendar tab is deliberately styled to feel close to native iOS Calendar.
final ThemeData butluTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: _scheme,
  scaffoldBackgroundColor: _scheme.surface,
  // FadeForwards reads as calmer/more modern than the default per-platform
  // transitions (Android's zoom, iOS's full swipe) -- one consistent feel
  // everywhere rather than something that looks different per platform.
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    },
  ),
  textTheme: const TextTheme(
    displaySmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
    titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleMedium: TextStyle(fontWeight: FontWeight.w600),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: _scheme.surfaceContainer,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.symmetric(vertical: 6),
  ),
  chipTheme: const ChipThemeData(
    shape: StadiumBorder(),
    padding: EdgeInsets.symmetric(horizontal: 4),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  ),
  listTileTheme: const ListTileThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    shape: const StadiumBorder(),
    backgroundColor: _scheme.primary,
    foregroundColor: _scheme.onPrimary,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: const StadiumBorder(),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 68,
    backgroundColor: _scheme.surfaceContainerLow,
    indicatorColor: _scheme.primary.withValues(alpha: 0.22),
    indicatorShape: const StadiumBorder(),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 12,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w600
            : FontWeight.w400,
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  appBarTheme: AppBarTheme(
    centerTitle: false,
    scrolledUnderElevation: 1,
    backgroundColor: _scheme.surface,
  ),
);
