import 'package:flutter/material.dart';

abstract final class TraelyxColors {
  // Provisional bootstrap tokens. The final palette remains subject to visual
  // prototyping and will stay centralized here and in theme-tokens.json.
  static const surfaceBase = Color(0xFF0B0E12);
  static const surfaceElevated = Color(0xFF151A20);
  static const surfaceOutline = Color(0xFF29313B);
  static const textPrimary = Color(0xFFF4F6F8);
  static const textSecondary = Color(0xFFA5AFBA);
  static const brandAccent = Color(0xFF7899FF);
  static const statusGood = Color(0xFF68D3A4);
  static const statusWarning = Color(0xFFF1B75A);
  static const statusSevere = Color(0xFFFF726E);
  static const statusInfo = Color(0xFF75B7FF);
}

abstract final class TraelyxTheme {
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: TraelyxColors.brandAccent,
      brightness: Brightness.dark,
      surface: TraelyxColors.surfaceBase,
      error: TraelyxColors.statusSevere,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: TraelyxColors.surfaceBase,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: TraelyxColors.textPrimary,
          fontSize: 38,
          fontWeight: FontWeight.w700,
          height: 1.05,
          letterSpacing: -1.2,
        ),
        headlineSmall: TextStyle(
          color: TraelyxColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: TraelyxColors.textPrimary,
          fontSize: 16,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: TraelyxColors.textSecondary,
          fontSize: 14,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          color: TraelyxColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      dividerColor: TraelyxColors.surfaceOutline,
      cardTheme: const CardThemeData(
        color: TraelyxColors.surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: TraelyxColors.surfaceOutline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
