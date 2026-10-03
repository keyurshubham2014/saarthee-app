import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// Design tokens used by the admin screens (02 §2.1, "Indigo and marigold").
///
/// Values come from the core [AppColors] tokens; a theme may override them
/// by registering an [AdminTokens] extension.
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
    ink: AppColors.ink,
    inkMuted: AppColors.inkMuted,
    marigold: AppColors.marigold,
    fixed: AppColors.fixed,
    fixedTint: AppColors.fixedTint,
    notFixed: AppColors.notFixed,
    notFixedTint: AppColors.notFixedTint,
    waitingTint: AppColors.waitingTint,
    neutralTint: AppColors.surface,
    indigoTint: AppColors.indigoTint,
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
