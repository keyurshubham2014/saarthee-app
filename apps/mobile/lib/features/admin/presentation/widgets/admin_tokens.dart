import 'package:flutter/material.dart';

/// Design tokens used by the admin screens (02 §2.1, "Indigo and marigold").
///
/// If the app theme registers an [AdminTokens] extension it wins; otherwise
/// the spec values below are used. These are the only colour literals in the
/// admin feature.
@immutable
class AdminTokens extends ThemeExtension<AdminTokens> {
  const AdminTokens({
    required this.ink,
    required this.inkMuted,
    required this.marigold,
    required this.fixed,
    required this.fixedTint,
    required this.notFixed,
    required this.notFixedTint,
    required this.waitingTint,
    required this.neutralTint,
    required this.indigoTint,
  });

  static const AdminTokens spec = AdminTokens(
    ink: Color(0xFF1B2433),
    inkMuted: Color(0xFF55607A),
    marigold: Color(0xFFF2B233),
    fixed: Color(0xFF1D6B43),
    fixedTint: Color(0xFFE2F1E8),
    notFixed: Color(0xFFA8321F),
    notFixedTint: Color(0xFFF8E4E0),
    waitingTint: Color(0xFFFDF1D6),
    neutralTint: Color(0xFFF6F7FB),
    indigoTint: Color(0xFFE6E9F5),
  );

  static AdminTokens of(BuildContext context) =>
      Theme.of(context).extension<AdminTokens>() ?? spec;

  final Color ink;
  final Color inkMuted;

  /// Attention fill (Due badge); always with [ink] text, never as text colour.
  final Color marigold;
  final Color fixed;
  final Color fixedTint;
  final Color notFixed;
  final Color notFixedTint;
  final Color waitingTint;
  final Color neutralTint;
  final Color indigoTint;

  @override
  AdminTokens copyWith() => this;

  @override
  AdminTokens lerp(AdminTokens? other, double t) => other ?? this;
}
