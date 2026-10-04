import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The Saarthee mark (DS §1): rounded square (radius 28% of size) in
/// `primary` with a white road that rises and turns right towards a `sunrise`
/// destination dot ("the way forward"). Master: docs/brand/mark.svg.
/// No seal, circle emblem, architecture or AMC colours.
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

  // Geometry in 100-unit mark space, copied from docs/brand/mark.svg
  // (variant E "road turn"); test/brand/brand_mark_test.dart checks them.
  /// `<rect id="square" rx="28">`
  static const double cornerRadius = 28;
  /// `<path id="route" d="M24 73 L24 51 Q24 33 42 33 L50 33">`
  static const Offset routeStart = Offset(24, 73);
  static const Offset routeTurnStart = Offset(24, 51);
  static const Offset routeTurnControl = Offset(24, 33);
  static const Offset routeTurnEnd = Offset(42, 33);
  static const Offset routeEnd = Offset(50, 33);
  /// `stroke-width="12"` (round caps and joins)
  static const double routeStroke = 12;
  /// `<circle id="dot" cx="72.5" cy="33" r="10.5">`
  static const Offset dotCenter = Offset(72.5, 33);
  static const double dotRadius = 10.5;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(cornerRadius * k),
      ),
      Paint()..color = square,
    );
    // Road rises from the lower left, turns right, runs on to the destination.
    final path = Path()
      ..moveTo(routeStart.dx * k, routeStart.dy * k)
      ..lineTo(routeTurnStart.dx * k, routeTurnStart.dy * k)
      ..quadraticBezierTo(
        routeTurnControl.dx * k,
        routeTurnControl.dy * k,
        routeTurnEnd.dx * k,
        routeTurnEnd.dy * k,
      )
      ..lineTo(routeEnd.dx * k, routeEnd.dy * k);
    canvas.drawPath(
      path,
      Paint()
        ..color = route
        ..style = PaintingStyle.stroke
        ..strokeWidth = routeStroke * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    canvas.drawCircle(dotCenter * k, dotRadius * k, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) =>
      old.square != square || old.route != route || old.dot != dot;
}

/// "Saarthee · સારથી" in Baloo Bhai 2 Bold, side by side, order swapped by
/// locale (never stacked English over Gujarati).
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 28, this.color});

  /// Brand names are proper nouns, identical in every locale (DS §1).
  static const String brandNameEn = 'Saarthee';
  static const String brandNameGu = 'સારથી';

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final gu = Localizations.localeOf(context).languageCode == 'gu';
    final first = gu ? brandNameGu : brandNameEn;
    final second = gu ? brandNameEn : brandNameGu;
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
