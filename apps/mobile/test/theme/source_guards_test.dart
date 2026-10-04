// T-03-03 (no style literals) and T-03-22 (no motion literals in features).
import 'package:flutter_test/flutter_test.dart';

import '../helpers/source_scan.dart';

void main() {
  group('T-03-03 no colour / fontSize / Icons. / v1 token literals', () {
    test('lib/ outside lib/core/theme/ is clean', () {
      final hits = scanFiles(
        dartFiles('lib', exclude: ['lib/core/theme/']),
        hasStyleLiteral,
      );
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    test('the rule catches each literal kind (fixture)', () {
      const bad = [
        "color: Color(0xFF000000),",
        "color: Colors.red,",
        "style: TextStyle(fontSize: 14),",
        "Icon(Icons.home)",
        "tokens.ink",
        "c.marigold",
        "c.secondaryContainer",
      ];
      for (final line in bad) {
        expect(hasStyleLiteral(line), isTrue, reason: line);
      }
      expect(hasStyleLiteral('color: Colors.transparent,'), isFalse);
      expect(hasStyleLiteral('Icon(SaartheeIcons.home)'), isFalse);
      expect(
        hasStyleLiteral(stripLineComment('// Colors.red in a comment')),
        isFalse,
      );
    });
  });

  group('T-03-22 no Duration( / Cubic( / Curves. under lib/features', () {
    test('lib/features (except dev/) is clean', () {
      final hits = scanFiles(
        dartFiles('lib/features', exclude: ['lib/features/dev/']),
        hasMotionLiteral,
      );
      expect(
        hits,
        isEmpty,
        reason: 'use SaartheeMotion / AppTimings:\n${hits.join('\n')}',
      );
    });

    test('a fixture file with literals fails the guard', () {
      const fixture = '''
final a = Duration(milliseconds: 300);
final b = Cubic(0.2, 0, 0, 1);
final c = Curves.easeOut;
final d = SaartheeMotion.medium.duration;
''';
      final hits = scanSource('fixture.dart', fixture, hasMotionLiteral);
      expect(hits.map((h) => h.line), [1, 2, 3]);
    });

    test('no AppMotion symbol exists in lib/', () {
      final hits = scanFiles(
        dartFiles('lib'),
        (code) => RegExp(r'\bAppMotion\b').hasMatch(code),
      );
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  });
}
