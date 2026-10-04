import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// Colours used by the v1 admin screens, mapped onto the Neem semantic
/// tokens (DS §2) so the console follows light and dark themes. TASK-10
/// replaces the console; until then the field names stay as in v1.
@immutable
class AdminTokens extends ThemeExtension<AdminTokens> {
  const AdminTokens({
    required this.text,
    required this.textMuted,
    required this.attention,
    required this.fixed,
    required this.fixedTint,
    required this.notFixed,
    required this.notFixedTint,
    required this.waitingTint,
    required this.neutralTint,
    required this.accentTint,
  });

  /// Derives the admin colours from the Neem tokens.
  factory AdminTokens.fromColors(SaartheeColors c) => AdminTokens(
    text: c.textPrimary,
    textMuted: c.textSecondary,
    attention: c.warningTint,
    fixed: c.success,
    fixedTint: c.successTint,
    notFixed: c.error,
    notFixedTint: c.errorTint,
    waitingTint: c.warningTint,
    neutralTint: c.surfaceAlt,
    accentTint: c.primaryContainer,
  );

  /// Light-theme values.
  static final AdminTokens spec = AdminTokens.fromColors(SaartheeColors.light);

  static AdminTokens of(BuildContext context) =>
      Theme.of(context).extension<AdminTokens>() ??
      AdminTokens.fromColors(SaartheeColors.of(context));

  final Color text;
  final Color textMuted;

  /// Attention fill (Due badge); always with [text] text, never as text colour.
  final Color attention;
  final Color fixed;
  final Color fixedTint;
  final Color notFixed;
  final Color notFixedTint;
  final Color waitingTint;
  final Color neutralTint;
  final Color accentTint;

  @override
  AdminTokens copyWith() => this;

  @override
  AdminTokens lerp(AdminTokens? other, double t) => other ?? this;
}
