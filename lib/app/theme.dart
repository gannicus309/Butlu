import 'package:flutter/material.dart';

/// Each tab's accent colour, in tab order: Calendar, Grocery, Inventory,
/// Chores, More. The tab bar and everything on that tab (buttons, chips,
/// highlights) take on its colour.
const List<Color> kTabAccents = [
  Color(0xFF0A84FF), // Calendar: blue, as most of it is office events.
  Color(0xFFFF5F57), // Grocery: coral, like the "To buy" tiles.
  Color(0xFF30C48D), // Inventory: fresh green.
  Color(0xFFFFB020), // Chores: amber.
  Color(0xFFA77BFF), // More: purple.
];

ColorScheme _schemeFor(Color seed) =>
    ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      // Keeps the accent itself recognisable (true coral, true amber)
      // rather than the muted pastel a plain seed scheme turns it into.
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
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
final ThemeData butluTheme = buildButluTheme(kTabAccents.first);

/// The app theme with [accent] as its main colour; see [kTabAccents].
ThemeData buildButluTheme(Color accent) {
  final scheme = _schemeFor(accent);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
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
      color: scheme.surfaceContainer,
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
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const StadiumBorder(),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primary.withValues(alpha: 0.28),
      indicatorShape: const StadiumBorder(),
      // The selected tab's icon and label in its own accent colour.
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
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
      backgroundColor: scheme.surface,
    ),
  );
}
