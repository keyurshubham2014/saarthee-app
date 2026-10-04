// T-03-01 token values (DS §2 v2.2) and T-03-02 WCAG contrast.
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/tokens.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  group('T-03-01 tokens', () {
    test('light palette equals DS §2 v2.2', () {
      const l = SaartheeColors.light;
      final expected = <String, (Color, int)>{
        'primary': (l.primary, 0xFF14674A),
        'onPrimary': (l.onPrimary, 0xFFFFFFFF),
        'primaryDark': (l.primaryDark, 0xFF0E4A35),
        'primaryContainer': (l.primaryContainer, 0xFFE1F0E7),
        'onPrimaryContainer': (l.onPrimaryContainer, 0xFF0E4A35),
        'onPrimarySubtle': (l.onPrimarySubtle, 0xFFBFE0CD),
        'sunrise': (l.sunrise, 0xFFC24A1F),
        'onSunrise': (l.onSunrise, 0xFFFFFFFF),
        'sunrisePressed': (l.sunrisePressed, 0xFFA33C17),
        'background': (l.background, 0xFFF3F6F1),
        'surface': (l.surface, 0xFFFFFFFF),
        'surfaceAlt': (l.surfaceAlt, 0xFFE8EFEA),
        'border': (l.border, 0xFFDCE5DE),
        'borderStrong': (l.borderStrong, 0xFF86978C),
        'textPrimary': (l.textPrimary, 0xFF17251E),
        'textSecondary': (l.textSecondary, 0xFF4E5E55),
        'textDisabled': (l.textDisabled, 0xFF8A978F),
        'success': (l.success, 0xFF1A7340),
        'successTint': (l.successTint, 0xFFE6F4EC),
        'warning': (l.warning, 0xFF9A5B00),
        'warningTint': (l.warningTint, 0xFFFFF4E0),
        'error': (l.error, 0xFFB3261E),
        'errorTint': (l.errorTint, 0xFFFCEBEA),
        'info': (l.info, 0xFF1F5FAE),
        'infoTint': (l.infoTint, 0xFFE5EEFA),
        'focusRing': (l.focusRing, 0xFFFFDD00),
        'focusInner': (l.focusInner, 0xFF17251E),
        'shadow': (l.shadow, 0xFF17251E),
      };
      expected.forEach((name, pair) {
        expect(pair.$1.toARGB32(), pair.$2, reason: name);
      });
    });

    test('dark palette anchors equal DS §2 dark line', () {
      const d = SaartheeColors.dark;
      expect(d.background.toARGB32(), 0xFF131C18);
      expect(d.surface.toARGB32(), 0xFF1A2520);
      expect(d.border.toARGB32(), 0xFF2A3830);
      expect(d.textPrimary.toARGB32(), 0xFFE6EFE9);
      expect(d.textSecondary.toARGB32(), 0xFFA9B9AF);
      expect(d.primary.toARGB32(), 0xFF7BD3A6);
      expect(d.onPrimary.toARGB32(), 0xFF0F1A15);
      expect(d.sunrise.toARGB32(), 0xFFFF9E78);
      expect(d.onSunrise.toARGB32(), 0xFF1B120D);
    });

    test('status, severity and category maps are complete', () {
      for (final s in IssueStatus.values) {
        expect(IssueStatusStyle.styles.containsKey(s), isTrue, reason: '$s');
      }
      expect(
        IssueStatusStyle.of(IssueStatus.sent).l10nKey,
        IssueStatusStyle.of(IssueStatus.acknowledged).l10nKey,
      );
      expect(AlertSeverityStyle.styles.length, 4);
      expect(CategoryStyle.all.length, 14);
      expect(CategoryStyle.of('nope').slug, 'other');
    });

    test('radii, spacing and sizes', () {
      expect(AppRadii.control, 14);
      expect(AppRadii.card, 18);
      expect(AppRadii.sheet, 24);
      expect(AppSpacing.scale, [4, 8, 12, 14, 16, 20, 24, 32, 40]);
      expect(AppSpacing.gutter, 16);
      expect(AppSpacing.cardGap, 14);
      expect(AppSpacing.buttonHeight, 50);
      expect(AppSpacing.pinnedButtonHeight, 56);
      expect(AppSpacing.reportCardMinHeight, 56);
      expect(AppSpacing.touchTarget, 48);
      expect(AppSpacing.categoryBadge, 40);
    });

    test('lerp interpolates between light and dark', () {
      final mid = SaartheeColors.light.lerp(SaartheeColors.dark, 1);
      expect(mid.primary, SaartheeColors.dark.primary);
    });
  });

  group('T-03-02 contrast (AA)', () {
    for (final c in [SaartheeColors.light, SaartheeColors.dark]) {
      final mode = c.isDark ? 'dark' : 'light';
      test('$mode text pairs ≥ 4.5', () {
        final pairs = <String, (Color, Color)>{
          'textPrimary/background': (c.textPrimary, c.background),
          'textPrimary/surface': (c.textPrimary, c.surface),
          'textSecondary/background': (c.textSecondary, c.background),
          'textSecondary/surface': (c.textSecondary, c.surface),
          'onPrimary/primary': (c.onPrimary, c.primary),
          'onSunrise/sunrise': (c.onSunrise, c.sunrise),
          'onPrimaryContainer/primaryContainer': (
            c.onPrimaryContainer,
            c.primaryContainer,
          ),
          'primary/surface': (c.primary, c.surface),
        };
        if (!c.isDark) {
          pairs['onPrimarySubtle/primary'] = (c.onPrimarySubtle, c.primary);
          pairs['onToast/primaryDark'] = (c.onToast, c.primaryDark);
        }
        pairs.forEach((name, p) {
          expect(contrast(p.$1, p.$2), greaterThanOrEqualTo(4.5), reason: name);
        });
      });

      test('$mode status and severity chips ≥ 4.5', () {
        for (final e in IssueStatusStyle.styles.entries) {
          final s = e.value;
          expect(
            contrast(s.chipForeground(c), s.chipBackground(c)),
            greaterThanOrEqualTo(4.5),
            reason: '${e.key}',
          );
        }
        for (final e in AlertSeverityStyle.styles.entries) {
          final s = e.value;
          expect(
            contrast(s.chipForeground(c), s.chipBackground(c)),
            greaterThanOrEqualTo(4.5),
            reason: '${e.key}',
          );
        }
      });

      test('$mode category glyph on tint ≥ 4.5', () {
        for (final cat in CategoryStyle.all) {
          expect(
            contrast(cat.glyph(c), cat.tint(c)),
            greaterThanOrEqualTo(4.5),
            reason: cat.slug,
          );
        }
      });

      test('$mode non-text UI ≥ 3.0', () {
        expect(contrast(c.borderStrong, c.surface), greaterThanOrEqualTo(3));
        expect(contrast(c.primary, c.background), greaterThanOrEqualTo(3));
      });
    }
  });
}
