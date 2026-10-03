import 'package:flutter/material.dart';

/// Design tokens "indigo and marigold" (02 §2.1). The only colour source.
class AppColors {
  const AppColors._();

  static const Color ink = Color(0xFF1B2433);
  static const Color inkMuted = Color(0xFF55607A);
  static const Color indigo = Color(0xFF2B3F87);
  static const Color indigoDark = Color(0xFF1E2C61);
  static const Color indigoTint = Color(0xFFE6E9F5);
  static const Color surface = Color(0xFFF6F7FB);
  static const Color white = Color(0xFFFFFFFF);
  static const Color fieldBorder = Color(0xFF7A849B);
  static const Color divider = Color(0xFFC9CEDB);
  static const Color marigold = Color(0xFFF2B233);
  static const Color fixed = Color(0xFF1D6B43);
  static const Color fixedTint = Color(0xFFE2F1E8);
  static const Color notFixed = Color(0xFFA8321F);
  static const Color notFixedTint = Color(0xFFF8E4E0);
  static const Color waitingTint = Color(0xFFFDF1D6);

  /// Scrim behind photos and stamps.
  static const Color scrim = Color(0x99000000);
  static const Color transparent = Color(0x00000000);
}

/// 4-point spacing scale (02 §2.1).
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal screen padding on phones.
  static const double screen = 20;

  /// Minimum touch target.
  static const double touchTarget = 48;

  /// Primary button minimum height.
  static const double primaryButtonHeight = 56;

  /// Max content width on large screens (02 §2.2).
  static const double maxContentWidth = 560;
}

/// Corner radii by hierarchy (02 §2.1).
class AppRadii {
  const AppRadii._();

  static const double control = 12;
  static const double card = 16;
  static const double sheet = 24;
  static const double chip = 999;

  static const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
}

/// Durations for functional motion; zero when reduce-motion is on.
class AppMotion {
  const AppMotion._();

  static const Duration step = Duration(milliseconds: 220);

  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;
}
