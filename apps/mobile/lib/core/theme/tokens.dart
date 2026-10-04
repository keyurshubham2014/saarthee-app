import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;

import 'icons.dart';

/// Neem semantic colour tokens (DS §2, design system v2.2). The only colour
/// source in the app: screens read them with `SaartheeColors.of(context)`.
///
/// Field names follow DS §2 exactly. Light values are the DS hex codes; dark
/// values follow the DS §2 dark line, with the remaining ones derived and
/// checked for contrast in `test/theme/contrast_test.dart` (T-03-02).
@immutable
class SaartheeColors extends ThemeExtension<SaartheeColors> {
  const SaartheeColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.onPrimarySubtle,
    required this.sunrise,
    required this.onSunrise,
    required this.sunrisePressed,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.error,
    required this.errorTint,
    required this.info,
    required this.infoTint,
    required this.focusRing,
    required this.focusInner,
    required this.shadow,
    required this.onToast,
    required this.offline,
    required this.offlineTint,
  });

  final Brightness brightness;
  final Color primary;
  final Color onPrimary;
  final Color primaryDark;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color onPrimarySubtle;

  /// Report actions only, at most once per screen (DS §2 rule).
  final Color sunrise;
  final Color onSunrise;
  final Color sunrisePressed;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Color error;
  final Color errorTint;
  final Color info;
  final Color infoTint;
  final Color focusRing;
  final Color focusInner;
  final Color shadow;

  /// Text on the `primaryDark` toast.
  final Color onToast;

  /// Slate offline banner (DS §5 banners).
  final Color offline;
  final Color offlineTint;

  bool get isDark => brightness == Brightness.dark;

  static const SaartheeColors light = SaartheeColors(
    brightness: Brightness.light,
    primary: Color(0xFF14674A),
    onPrimary: Color(0xFFFFFFFF),
    primaryDark: Color(0xFF0E4A35),
    primaryContainer: Color(0xFFE1F0E7),
    onPrimaryContainer: Color(0xFF0E4A35),
    onPrimarySubtle: Color(0xFFBFE0CD),
    sunrise: Color(0xFFC24A1F),
    onSunrise: Color(0xFFFFFFFF),
    sunrisePressed: Color(0xFFA33C17),
    background: Color(0xFFF3F6F1),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE8EFEA),
    border: Color(0xFFDCE5DE),
    borderStrong: Color(0xFF86978C),
    textPrimary: Color(0xFF17251E),
    textSecondary: Color(0xFF4E5E55),
    textDisabled: Color(0xFF8A978F),
    success: Color(0xFF1A7340),
    successTint: Color(0xFFE6F4EC),
    warning: Color(0xFF9A5B00),
    warningTint: Color(0xFFFFF4E0),
    error: Color(0xFFB3261E),
    errorTint: Color(0xFFFCEBEA),
    info: Color(0xFF1F5FAE),
    infoTint: Color(0xFFE5EEFA),
    focusRing: Color(0xFFFFDD00),
    focusInner: Color(0xFF17251E),
    shadow: Color(0xFF17251E),
    onToast: Color(0xFFFFFFFF),
    offline: Color(0xFF4B5768),
    offlineTint: Color(0xFFEDF0F4),
  );

  static const SaartheeColors dark = SaartheeColors(
    brightness: Brightness.dark,
    primary: Color(0xFF7BD3A6),
    onPrimary: Color(0xFF0F1A15),
    primaryDark: Color(0xFF0E4A35),
    primaryContainer: Color(0xFF1E3D30),
    onPrimaryContainer: Color(0xFFBFE0CD),
    onPrimarySubtle: Color(0xFF1E4A37),
    sunrise: Color(0xFFFF9E78),
    onSunrise: Color(0xFF1B120D),
    sunrisePressed: Color(0xFFFFB899),
    background: Color(0xFF131C18),
    surface: Color(0xFF1A2520),
    surfaceAlt: Color(0xFF243129),
    border: Color(0xFF2A3830),
    borderStrong: Color(0xFF6E8578),
    textPrimary: Color(0xFFE6EFE9),
    textSecondary: Color(0xFFA9B9AF),
    textDisabled: Color(0xFF6B7A71),
    success: Color(0xFF8AD5A6),
    successTint: Color(0xFF173325),
    warning: Color(0xFFF0BC6A),
    warningTint: Color(0xFF382A12),
    error: Color(0xFFFFB4AB),
    errorTint: Color(0xFF3D1C19),
    info: Color(0xFFA9C8F4),
    infoTint: Color(0xFF16283F),
    focusRing: Color(0xFFFFDD00),
    focusInner: Color(0xFF17251E),
    shadow: Color(0xFF000000),
    onToast: Color(0xFFE6EFE9),
    offline: Color(0xFFC9D1DC),
    offlineTint: Color(0xFF252E38),
  );

  /// Tokens of the current theme (light when no extension is registered).
  static SaartheeColors of(BuildContext context) =>
      Theme.of(context).extension<SaartheeColors>() ?? light;

  @override
  SaartheeColors copyWith({Color? primary, Color? sunrise}) => SaartheeColors(
    brightness: brightness,
    primary: primary ?? this.primary,
    onPrimary: onPrimary,
    primaryDark: primaryDark,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    onPrimarySubtle: onPrimarySubtle,
    sunrise: sunrise ?? this.sunrise,
    onSunrise: onSunrise,
    sunrisePressed: sunrisePressed,
    background: background,
    surface: surface,
    surfaceAlt: surfaceAlt,
    border: border,
    borderStrong: borderStrong,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textDisabled: textDisabled,
    success: success,
    successTint: successTint,
    warning: warning,
    warningTint: warningTint,
    error: error,
    errorTint: errorTint,
    info: info,
    infoTint: infoTint,
    focusRing: focusRing,
    focusInner: focusInner,
    shadow: shadow,
    onToast: onToast,
    offline: offline,
    offlineTint: offlineTint,
  );

  @override
  SaartheeColors lerp(SaartheeColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SaartheeColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryDark: l(primaryDark, other.primaryDark),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      onPrimarySubtle: l(onPrimarySubtle, other.onPrimarySubtle),
      sunrise: l(sunrise, other.sunrise),
      onSunrise: l(onSunrise, other.onSunrise),
      sunrisePressed: l(sunrisePressed, other.sunrisePressed),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textDisabled: l(textDisabled, other.textDisabled),
      success: l(success, other.success),
      successTint: l(successTint, other.successTint),
      warning: l(warning, other.warning),
      warningTint: l(warningTint, other.warningTint),
      error: l(error, other.error),
      errorTint: l(errorTint, other.errorTint),
      info: l(info, other.info),
      infoTint: l(infoTint, other.infoTint),
      focusRing: l(focusRing, other.focusRing),
      focusInner: l(focusInner, other.focusInner),
      shadow: l(shadow, other.shadow),
      onToast: l(onToast, other.onToast),
      offline: l(offline, other.offline),
      offlineTint: l(offlineTint, other.offlineTint),
    );
  }
}

/// Fixed white and transparent, for the few places the DS names them
/// ("white on `primary`", "white 14%" header buttons).
class NeemFixed {
  const NeemFixed._();

  static const Color white = Color(0xFFFFFFFF);
  static const Color transparent = Color(0x00000000);

  /// Scrim behind full-screen photos.
  static const Color scrim = Color(0x99000000);

  /// Header buttons: white at 14% on the green band (DS §5).
  static const Color headerButton = Color(0x24FFFFFF);
}

/// A solid/tint pair with an icon and its l10n key (status, severity).
@immutable
class ToneStyle {
  const ToneStyle({
    required this.solid,
    required this.tint,
    required this.icon,
    required this.l10nKey,
  });

  final Color solid;
  final Color tint;
  final IconData icon;

  /// ARB key of the word shown next to the icon.
  final String l10nKey;

  /// Chip background / text for the current brightness. In dark mode the
  /// tint becomes the text on `surfaceAlt` and the solid stays for dots/bars
  /// (DS §2 dark line).
  Color chipBackground(SaartheeColors c) => c.isDark ? c.surfaceAlt : tint;
  Color chipForeground(SaartheeColors c) => c.isDark ? tint : solid;
}

/// v2 issue statuses (DS §2). `sent` shares the `acknowledged` style.
enum IssueStatus {
  reported,
  sent,
  acknowledged,
  inProgress,
  markedFixed,
  verified,
  reopened,
  rejected,
}

class IssueStatusStyle {
  const IssueStatusStyle._();

  static const Map<IssueStatus, ToneStyle> styles = {
    IssueStatus.reported: ToneStyle(
      solid: Color(0xFF4B5768),
      tint: Color(0xFFEDF0F4),
      icon: SaartheeIcons.statusReported,
      l10nKey: 'statusReported',
    ),
    IssueStatus.sent: ToneStyle(
      solid: Color(0xFF1F5FAE),
      tint: Color(0xFFE5EEFA),
      icon: SaartheeIcons.statusAcknowledged,
      l10nKey: 'statusAcknowledged',
    ),
    IssueStatus.acknowledged: ToneStyle(
      solid: Color(0xFF1F5FAE),
      tint: Color(0xFFE5EEFA),
      icon: SaartheeIcons.statusAcknowledged,
      l10nKey: 'statusAcknowledged',
    ),
    IssueStatus.inProgress: ToneStyle(
      solid: Color(0xFF8A5300),
      tint: Color(0xFFFFF3DC),
      icon: SaartheeIcons.statusInProgress,
      l10nKey: 'statusInProgress',
    ),
    IssueStatus.markedFixed: ToneStyle(
      solid: Color(0xFF1A7340),
      tint: Color(0xFFE6F4EC),
      icon: SaartheeIcons.statusFixed,
      l10nKey: 'statusFixed',
    ),
    IssueStatus.verified: ToneStyle(
      solid: Color(0xFF0E5233),
      tint: Color(0xFFDDEFE5),
      icon: SaartheeIcons.statusVerified,
      l10nKey: 'statusVerified',
    ),
    IssueStatus.reopened: ToneStyle(
      solid: Color(0xFFB4400F),
      tint: Color(0xFFFDEDE4),
      icon: SaartheeIcons.statusReopened,
      l10nKey: 'statusReopened',
    ),
    IssueStatus.rejected: ToneStyle(
      solid: Color(0xFF8A2234),
      tint: Color(0xFFF8E7EA),
      icon: SaartheeIcons.statusRejected,
      l10nKey: 'statusRejected',
    ),
  };

  static ToneStyle of(IssueStatus s) => styles[s]!;
}

/// Alert severities (DS §2 severity line).
enum AlertSeverity { info, advisory, warning, critical }

class AlertSeverityStyle {
  const AlertSeverityStyle._();

  static const Map<AlertSeverity, ToneStyle> styles = {
    AlertSeverity.info: ToneStyle(
      solid: Color(0xFF1F5FAE),
      tint: Color(0xFFE5EEFA),
      icon: SaartheeIcons.severityInfo,
      l10nKey: 'severityInfo',
    ),
    AlertSeverity.advisory: ToneStyle(
      solid: Color(0xFF6F5A00),
      tint: Color(0xFFFBF5D9),
      icon: SaartheeIcons.severityAdvisory,
      l10nKey: 'severityAdvisory',
    ),
    AlertSeverity.warning: ToneStyle(
      solid: Color(0xFFA34A00),
      tint: Color(0xFFFFEEDD),
      icon: SaartheeIcons.severityWarning,
      l10nKey: 'severityWarning',
    ),
    AlertSeverity.critical: ToneStyle(
      solid: Color(0xFFB3261E),
      tint: Color(0xFFFCEBEA),
      icon: SaartheeIcons.severityCritical,
      l10nKey: 'severityCritical',
    ),
  };

  static ToneStyle of(AlertSeverity s) => styles[s]!;
}

/// Category colour + glyph (DS §2 categories). The tint is the colour at 12%
/// over `surface`; in dark mode the glyph is lightened and the tint deepened
/// so the pair keeps ≥ 4.5:1 (T-03-02).
@immutable
class CategoryStyle {
  const CategoryStyle({
    required this.slug,
    required this.color,
    required this.icon,
  });

  final String slug;
  final Color color;
  final IconData icon;

  static const Color _darkSurface = Color(0xFF1A2520);
  static const Color _white = Color(0xFFFFFFFF);

  /// Glyph colour on the badge.
  Color glyph(SaartheeColors c) =>
      c.isDark ? painting.Color.lerp(color, _white, 0.55)! : color;

  /// Badge fill.
  Color tint(SaartheeColors c) => c.isDark
      ? painting.Color.lerp(_darkSurface, color, 0.30)!
      : painting.Color.lerp(c.surface, color, 0.12)!;

  /// The 14 slugs in DS order. `other` is the fallback.
  static const List<CategoryStyle> all = [
    CategoryStyle(
      slug: 'roads',
      color: Color(0xFF5A5F66),
      icon: SaartheeIcons.catRoads,
    ),
    CategoryStyle(
      slug: 'water',
      color: Color(0xFF1D5E9E),
      icon: SaartheeIcons.catWater,
    ),
    CategoryStyle(
      slug: 'drainage',
      color: Color(0xFF3F5E73),
      icon: SaartheeIcons.catDrainage,
    ),
    CategoryStyle(
      slug: 'garbage',
      color: Color(0xFF5C6B2E),
      icon: SaartheeIcons.catGarbage,
    ),
    CategoryStyle(
      slug: 'streetlight',
      color: Color(0xFF8A5F00),
      icon: SaartheeIcons.catStreetlight,
    ),
    CategoryStyle(
      slug: 'trees',
      color: Color(0xFF2E6B45),
      icon: SaartheeIcons.catTrees,
    ),
    CategoryStyle(
      slug: 'animals',
      color: Color(0xFF7A4E2D),
      icon: SaartheeIcons.catAnimals,
    ),
    CategoryStyle(
      slug: 'health',
      color: Color(0xFF7A3F6B),
      icon: SaartheeIcons.catHealth,
    ),
    CategoryStyle(
      slug: 'toilets',
      color: Color(0xFF2F6670),
      icon: SaartheeIcons.catToilets,
    ),
    CategoryStyle(
      slug: 'encroachment',
      color: Color(0xFF8C3B2E),
      icon: SaartheeIcons.catEncroachment,
    ),
    CategoryStyle(
      slug: 'traffic',
      color: Color(0xFF9C3D1A),
      icon: SaartheeIcons.catTraffic,
    ),
    CategoryStyle(
      slug: 'property',
      color: Color(0xFF4F5A7A),
      icon: SaartheeIcons.catProperty,
    ),
    CategoryStyle(
      slug: 'building',
      color: Color(0xFF6B4F3A),
      icon: SaartheeIcons.catBuilding,
    ),
    // DS #66707C measured 4.33:1 on its tint; darkened to pass 4.5 (T-03-02).
    CategoryStyle(
      slug: 'other',
      color: Color(0xFF5E6874),
      icon: SaartheeIcons.catOther,
    ),
  ];

  static final Map<String, CategoryStyle> bySlug = {
    for (final c in all) c.slug: c,
  };

  static CategoryStyle get fallback => all.last;

  static CategoryStyle of(String slug) => bySlug[slug] ?? fallback;
}

/// 4 dp spacing scale and layout constants (DS §4).
class AppSpacing {
  const AppSpacing._();

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;

  static const List<double> scale = [4, 8, 12, 14, 16, 20, 24, 32, 40];

  static const double gutter = 16;
  static const double cardGap = 14;
  static const double sectionTitleTop = 24;
  static const double sectionTitleBottom = 12;
  static const double maxContent = 600;
  static const double staffMaxContent = 1200;
  static const double touchTarget = 48;
  static const double buttonHeight = 50;
  static const double pinnedButtonHeight = 56;
  static const double reportCardMinHeight = 56;
  static const double categoryBadge = 40;
  static const double headerButton = 36;
  static const double emptyIcon = 56;
  static const double timelineDot = 14;
  static const double iconSize = 24;
  static const double iconSmall = 18;
  static const double borderWidth = 1;
  static const double outlineWidth = 1.5;
  static const double focusWidth = 2;
}

/// Corner radii (DS §4).
class AppRadii {
  const AppRadii._();

  static const double control = 14;
  static const double card = 18;
  static const double sheet = 24;

  /// Brand mark corner radius as a fraction of its size.
  static const double markFraction = 0.28;

  static const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
  static const StadiumBorder pill = StadiumBorder();
}

/// Elevation recipes (DS §4).
class AppElevation {
  const AppElevation._();

  static const double overlay = 3;

  /// Cards: 1 px `border` plus a 1 dp soft shadow (`shadow` at 5%).
  static List<BoxShadow> card(SaartheeColors c) => [
    BoxShadow(
      color: c.shadow.withValues(alpha: 0.05),
      offset: const Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// Report card glow: `sunrise` 0 10 22 −10 at 70%.
  static List<BoxShadow> reportGlow(SaartheeColors c) => [
    BoxShadow(
      color: c.sunrise.withValues(alpha: 0.7),
      offset: const Offset(0, 10),
      blurRadius: 22,
      spreadRadius: -10,
    ),
  ];

  static BoxDecoration cardDecoration(SaartheeColors c) => BoxDecoration(
    color: c.surface,
    borderRadius: AppRadii.cardRadius,
    border: Border.all(color: c.border),
    boxShadow: card(c),
  );
}
