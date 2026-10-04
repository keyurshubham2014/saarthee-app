import 'package:flutter/material.dart';

import 'tokens.dart';

/// DS §3 typography: Baloo Bhai 2 for display, headings and numbers; Mukta
/// Vaani for body, labels, buttons and metadata. Bundled subset fonts; the
/// Android system Noto fonts are named only as fallback.
class AppTypography {
  const AppTypography._();

  static const String heading = 'BalooBhai2';
  static const String body = 'MuktaVaani';
  static const List<String> fallback = ['NotoSansGujarati', 'NotoSans'];

  /// Baloo is never used below this size (DS §3 rule).
  static const double balooMinSize = 16;

  /// No text below this size (DS §3 rule).
  static const double minSize = 12;

  static TextStyle _style(
    String family,
    double size,
    FontWeight weight,
    double lineHeight,
    Color color, {
    List<FontFeature>? features,
  }) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight,
    height: lineHeight / size,
    letterSpacing: 0,
    color: color,
    fontFeatures: features,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The DS §3 roles mapped onto Material roles.
  static TextTheme textTheme(SaartheeColors c) {
    final p = c.textPrimary;
    final s = c.textSecondary;
    final display = _style(heading, 28, FontWeight.w700, 36, p);
    final headline = _style(heading, 24, FontWeight.w700, 32, p);
    final titleL = _style(heading, 19, FontWeight.w600, 26, p);
    final titleM = _style(body, 16, FontWeight.w600, 22, p);
    final bodyL = _style(body, 16, FontWeight.w400, 24, p);
    final bodyM = _style(body, 14, FontWeight.w400, 21, p);
    final bodyS = _style(body, 12, FontWeight.w400, 17, s);
    final labelL = _style(body, 15.5, FontWeight.w600, 20, p);
    final labelM = _style(body, 12, FontWeight.w600, 16, p);
    return TextTheme(
      displayLarge: display,
      displayMedium: display,
      displaySmall: display,
      headlineLarge: headline,
      headlineMedium: headline,
      headlineSmall: headline,
      titleLarge: titleL,
      titleMedium: titleM,
      titleSmall: titleM,
      bodyLarge: bodyL,
      bodyMedium: bodyM,
      bodySmall: bodyS,
      labelLarge: labelL,
      labelMedium: labelM,
      labelSmall: labelM,
    );
  }

  /// Stat tiles and counts: Baloo Bhai 2 20/700/24 with tabular figures
  /// (Baloo Bhai 2 ships `tnum`, checked in T-03-04).
  static TextStyle numeric(SaartheeColors c) => _style(
    heading,
    20,
    FontWeight.w700,
    24,
    c.textPrimary,
    features: const [FontFeature.tabularFigures()],
  );

  /// Display numbers (success issue number, scorecard): Baloo 800.
  static TextStyle displayNumber(SaartheeColors c) => _style(
    heading,
    28,
    FontWeight.w800,
    36,
    c.textPrimary,
    features: const [FontFeature.tabularFigures()],
  );

  /// Wordmark: Baloo Bhai 2 Bold at [size].
  static TextStyle wordmark(Color color, double size) =>
      _style(heading, size, FontWeight.w700, size * 1.3, color);
}
