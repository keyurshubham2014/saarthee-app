// T-03-17 (ARB parity) and T-03-18 (no hard-coded strings).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/source_scan.dart';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/core/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// Placeholder names used in a message (ICU arguments and plain `{x}`).
Set<String> _placeholders(String message) =>
    RegExp(r'\{(\w+)[,}]').allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  final en = _arb('app_en.arb');
  final gu = _arb('app_gu.arb');

  group('T-03-17 ARB parity', () {
    test('locales are declared', () {
      expect(en['@@locale'], 'en');
      expect(gu['@@locale'], 'gu');
    });

    test('same key set in en and gu', () {
      final enKeys = _messageKeys(en);
      final guKeys = _messageKeys(gu);
      expect(enKeys.difference(guKeys), isEmpty, reason: 'missing in gu');
      expect(guKeys.difference(enKeys), isEmpty, reason: 'missing in en');
    });

    test('same placeholders and no empty values', () {
      for (final k in _messageKeys(en)) {
        final e = en[k] as String;
        final g = gu[k] as String;
        expect(e.trim(), isNotEmpty, reason: 'en $k empty');
        expect(g.trim(), isNotEmpty, reason: 'gu $k empty');
        expect(_placeholders(g), _placeholders(e), reason: k);
      }
    });

    test('Gujarati drafts are marked for native review', () {
      for (final k in _messageKeys(gu)) {
        final meta = gu['@$k'];
        expect(meta, isA<Map<String, dynamic>>(), reason: k);
        expect((meta as Map)['x-review'], 'pending', reason: k);
      }
    });

    test('no retired v1 key prefixes remain', () {
      final retired = RegExp(
        r'^(invite|welcome|verify|reportStep|reportDraft)',
      );
      final hits = _messageKeys(en).where(retired.hasMatch).toList();
      expect(hits, isEmpty, reason: hits.join(', '));
    });
  });

  group('T-03-18 no hard-coded strings', () {
    test('lib/features and lib/core/widgets use ARB strings', () {
      final files = [
        ...dartFiles('lib/features', exclude: ['lib/features/dev/']),
        ...dartFiles('lib/core/widgets'),
      ];
      final hits = scanFiles(files, hasHardcodedString);
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    test('the rule catches literals and allows interpolation (fixture)', () {
      expect(hasHardcodedString("Text('Hello')"), isTrue);
      expect(hasHardcodedString("tooltip: 'Close'"), isTrue);
      expect(hasHardcodedString("label: 'નમસ્તે'"), isTrue);
      expect(hasHardcodedString(r"Text('${l10n.appTitle}')"), isFalse);
      expect(hasHardcodedString(r"label: '$label $value'"), isFalse);
      expect(hasHardcodedString("Text(l10n.appTitle)"), isFalse);
    });
  });
}
