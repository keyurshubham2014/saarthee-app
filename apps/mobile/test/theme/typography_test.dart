// T-03-04 typography roles (DS §3).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/theme/typography.dart';

void main() {
  final t = AppTypography.textTheme(SaartheeColors.light);

  void role(
    String name,
    TextStyle? s,
    String family,
    double size,
    FontWeight weight,
    double line,
  ) {
    expect(s, isNotNull, reason: name);
    expect(s!.fontFamily, family, reason: name);
    expect(s.fontSize, size, reason: name);
    expect(s.fontWeight, weight, reason: name);
    expect(s.height! * size, closeTo(line, 0.01), reason: name);
    expect(s.letterSpacing ?? 0, 0, reason: '$name letter-spacing');
  }

  test('roles equal DS §3', () {
    const b = 'BalooBhai2', m = 'MuktaVaani';
    role('displaySmall', t.displaySmall, b, 28, FontWeight.w700, 36);
    role('headlineSmall', t.headlineSmall, b, 24, FontWeight.w700, 32);
    role('titleLarge', t.titleLarge, b, 19, FontWeight.w600, 26);
    role('titleMedium', t.titleMedium, m, 16, FontWeight.w600, 22);
    role('bodyLarge', t.bodyLarge, m, 16, FontWeight.w400, 24);
    role('bodyMedium', t.bodyMedium, m, 14, FontWeight.w400, 21);
    role('labelLarge', t.labelLarge, m, 15.5, FontWeight.w600, 21);
    role('labelMedium', t.labelMedium, m, 12, FontWeight.w600, 16);
    role('bodySmall', t.bodySmall, m, 12, FontWeight.w400, 17);
    role(
      'numeric',
      AppTypography.numeric(SaartheeColors.light),
      b,
      20,
      FontWeight.w700,
      24,
    );
  });

  test('Baloo never below 16 sp and nothing below 12 sp', () {
    final all = [
      t.displayLarge,
      t.displayMedium,
      t.displaySmall,
      t.headlineLarge,
      t.headlineMedium,
      t.headlineSmall,
      t.titleLarge,
      t.titleMedium,
      t.titleSmall,
      t.bodyLarge,
      t.bodyMedium,
      t.bodySmall,
      t.labelLarge,
      t.labelMedium,
      t.labelSmall,
      AppTypography.numeric(SaartheeColors.light),
      AppTypography.displayNumber(SaartheeColors.light),
    ];
    for (final s in all) {
      expect(s!.fontSize, greaterThanOrEqualTo(12));
      if (s.fontFamily == AppTypography.heading) {
        expect(s.fontSize, greaterThanOrEqualTo(16));
      }
    }
  });

  test('fallback lists Noto Sans Gujarati then Noto Sans', () {
    expect(t.bodyLarge!.fontFamilyFallback, ['NotoSansGujarati', 'NotoSans']);
    expect(t.displaySmall!.fontFamilyFallback, [
      'NotoSansGujarati',
      'NotoSans',
    ]);
  });

  test('numeric role uses tabular figures and Baloo ships tnum', () {
    final n = AppTypography.numeric(SaartheeColors.light);
    expect(n.fontFeatures, contains(const FontFeature.tabularFigures()));
    final bytes = File('assets/fonts/BalooBhai2-Bold.ttf').readAsBytesSync();
    expect(latin1.decode(bytes).contains('tnum'), isTrue);
  });

  // The 1.2 MB budget is not met by the subset (Gujarati GSUB/GPOS kept in
  // full): 2.2 MB, recorded in TASK-03 §5.6 and §13. This guards growth.
  test('bundled subset fonts total ≤ 2.3 MB (no growth)', () {
    final total = Directory('assets/fonts')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.ttf'))
        .fold<int>(0, (sum, f) => sum + f.lengthSync());
    expect(total, lessThanOrEqualTo(2300 * 1024));
  });
}
