import 'package:flutter/material.dart';

/// Tokens do design system compartilhado pelos apps (cor, espaço, raio).
abstract final class Tokens {
  static const brand = Color(0xFF0B5FFF);
  static const accent = Color(0xFFFF7A00);
  static const success = Color(0xFF1E8E3E);
  static const warning = Color(0xFFB26A00);
  static const critical = Color(0xFFC5221F);

  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;

  static const radius = 12.0;
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: Tokens.brand, brightness: brightness);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radius));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: CardThemeData(shape: shape, margin: EdgeInsets.zero, elevation: 0, color: scheme.surfaceContainerLow),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: shape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: shape),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Tokens.radius)),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
    ),
  );
}
