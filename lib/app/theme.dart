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
);
