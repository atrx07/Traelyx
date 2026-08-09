import 'package:flutter/material.dart';

/// Raw dark-first palette values.
///
/// Widgets should consume [TraelyxSemanticColors] so a color's meaning stays
/// explicit if the visual palette evolves.
abstract final class TraelyxPalette {
  static const ink950 = Color(0xFF0B0E12);
  static const ink900 = Color(0xFF131820);
  static const ink850 = Color(0xFF1B222C);
  static const ink700 = Color(0xFF313B47);
  static const ink600 = Color(0xFF465467);
  static const ink300 = Color(0xFFA5AFBA);
  static const ink50 = Color(0xFFF4F6F8);

  static const blue400 = Color(0xFF87A5FF);
  static const sky400 = Color(0xFF75B7FF);
  static const green400 = Color(0xFF68D3A4);
  static const amber400 = Color(0xFFF1B75A);
  static const red400 = Color(0xFFFF726E);

  static const onBlue = Color(0xFF071432);
  static const onRed = Color(0xFF280405);
}

/// Semantic colors that are not fully represented by Material's color scheme.
@immutable
class TraelyxSemanticColors extends ThemeExtension<TraelyxSemanticColors> {
  const TraelyxSemanticColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.outline,
    required this.outlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.positive,
    required this.caution,
    required this.critical,
    required this.information,
  });

  static const dark = TraelyxSemanticColors(
    canvas: TraelyxPalette.ink950,
    surface: TraelyxPalette.ink900,
    surfaceRaised: TraelyxPalette.ink850,
    outline: TraelyxPalette.ink700,
    outlineStrong: TraelyxPalette.ink600,
    textPrimary: TraelyxPalette.ink50,
    textSecondary: TraelyxPalette.ink300,
    accent: TraelyxPalette.blue400,
    onAccent: TraelyxPalette.onBlue,
    positive: TraelyxPalette.green400,
    caution: TraelyxPalette.amber400,
    critical: TraelyxPalette.red400,
    information: TraelyxPalette.sky400,
  );

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color outline;
  final Color outlineStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color onAccent;
  final Color positive;
  final Color caution;
  final Color critical;
  final Color information;

  static TraelyxSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<TraelyxSemanticColors>() ?? dark;
  }

  @override
  TraelyxSemanticColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? outline,
    Color? outlineStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
    Color? positive,
    Color? caution,
    Color? critical,
    Color? information,
  }) {
    return TraelyxSemanticColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      outline: outline ?? this.outline,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      positive: positive ?? this.positive,
      caution: caution ?? this.caution,
      critical: critical ?? this.critical,
      information: information ?? this.information,
    );
  }

  @override
  TraelyxSemanticColors lerp(covariant TraelyxSemanticColors? other, double t) {
    if (other == null) {
      return this;
    }

    return TraelyxSemanticColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      information: Color.lerp(information, other.information, t)!,
    );
  }
}

/// Four-point spacing scale used across application layouts.
abstract final class TraelyxSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 48;
  static const double hero = 72;
}

abstract final class TraelyxRadii {
  static const double compact = 8;
  static const double control = 14;
  static const double card = 18;
  static const double panel = 24;
  static const double pill = 999;
}

/// Restrained motion primitives. Always resolve durations through
/// [effectiveDuration] when an animation is user-visible.
abstract final class TraelyxMotion {
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 360);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubic;

  static Duration effectiveDuration(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}

abstract final class TraelyxTheme {
  static ThemeData get dark {
    const colors = TraelyxSemanticColors.dark;
    final colorScheme = ColorScheme.dark(
      primary: colors.accent,
      onPrimary: colors.onAccent,
      secondary: colors.information,
      onSecondary: colors.onAccent,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      error: colors.critical,
      onError: TraelyxPalette.onRed,
      outline: colors.outlineStrong,
      outlineVariant: colors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      extensions: [colors],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: 56,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: -2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        displayMedium: TextStyle(
          color: colors.textPrimary,
          fontSize: 44,
          fontWeight: FontWeight.w700,
          height: 1.02,
          letterSpacing: -1.6,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        displaySmall: TextStyle(
          color: colors.textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          height: 1.06,
          letterSpacing: -1.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        headlineLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w600,
          height: 1.15,
          letterSpacing: -0.7,
        ),
        headlineMedium: TextStyle(
          color: colors.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.18,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          color: colors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.25,
        ),
        titleLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        titleMedium: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        bodyLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: colors.textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelMedium: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      dividerColor: colors.outline,
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(TraelyxRadii.card)),
          side: BorderSide(color: colors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          disabledBackgroundColor: colors.surfaceRaised,
          disabledForegroundColor: colors.textSecondary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TraelyxRadii.control),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.surfaceRaised,
        circularTrackColor: colors.surfaceRaised,
      ),
    );
  }
}

extension TraelyxThemeContext on BuildContext {
  TraelyxSemanticColors get traelyxColors => TraelyxSemanticColors.of(this);
}
