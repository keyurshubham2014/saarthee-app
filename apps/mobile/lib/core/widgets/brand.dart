import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The Saarthee mark (DS §1): rounded square (radius 28% of size) in
/// `primary` with a white upward-right route chevron ending in a `sunrise`
/// dot. No seal, circle emblem, architecture or AMC colours.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72, this.semanticLabel});

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Semantics(
      label: semanticLabel ?? AppLocalizations.of(context).appTitle,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: BrandMarkPainter(
            // The mark is always the light brand green, also in dark mode.
            square: SaartheeColors.light.primary,
            route: NeemFixed.white,
            dot: c.isDark ? SaartheeColors.light.sunrise : c.sunrise,
          ),
        ),
      ),
    );
  }
}

class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({
    required this.square,
    required this.route,
    required this.dot,
  });

  final Color square;
  final Color route;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = s * AppRadii.markFraction;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)),
      Paint()..color = square,
    );
    // Route: rises from the lower left, turns, and heads up-right.
    final path = Path()
      ..moveTo(s * 0.24, s * 0.74)
      ..lineTo(s * 0.44, s * 0.54)
      ..lineTo(s * 0.54, s * 0.62)
      ..lineTo(s * 0.70, s * 0.40);
    canvas.drawPath(
      path,
      Paint()
        ..color = route
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      Offset(s * 0.74, s * 0.30),
      s * 0.085,
      Paint()..color = dot,
    );
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) =>
      old.square != square || old.route != route || old.dot != dot;
}

/// "Saarthee · સારથી" in Baloo Bhai 2 Bold, side by side, order swapped by
/// locale (never stacked English over Gujarati).
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final gu = Localizations.localeOf(context).languageCode == 'gu';
    final first = gu ? l10n.brandNameGu : l10n.brandNameEn;
    final second = gu ? l10n.brandNameEn : l10n.brandNameGu;
    return Semantics(
      header: true,
      label: l10n.appTitle,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(text: '$first · $second'),
        style: AppTypography.wordmark(color ?? c.textPrimary, size),
        textAlign: TextAlign.center,
      ),
    );
  }
}
