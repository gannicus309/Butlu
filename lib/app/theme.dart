import 'package:flutter/material.dart';

/// Dark theme by default, blue accent matching iOS system blue -- the
/// Calendar tab is deliberately styled to feel close to native iOS Calendar.
final ThemeData butluTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0A84FF),
    brightness: Brightness.dark,
  ),
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
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.symmetric(vertical: 6),
  ),
  chipTheme: const ChipThemeData(
    shape: StadiumBorder(),
    padding: EdgeInsets.symmetric(horizontal: 4),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  ),
  listTileTheme: const ListTileThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    shape: StadiumBorder(),
  ),
  appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 1),
);
