// V2-TASK-14 step 8 / AC-1: shared matrix for DS §5 component tests.
//
// Every component is pumped in `en` and `gu`, at text scale 1.0 and 2.0,
// on a 360 dp wide phone. Each case pumps twice — once with motion and
// once with `MediaQuery.disableAnimations: true` — and asserts no
// exception (layout overflow is a FlutterError), the caller's semantics
// checks, and that the rendered text is identical in both passes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';

import 'motion.dart';

typedef ComponentBuilder = Widget Function(AppLocalizations l10n);
typedef ComponentCheck =
    Future<void> Function(WidgetTester t, AppLocalizations l10n);

const matrixLocales = [Locale('en'), Locale('gu')];
const matrixScales = [1.0, 2.0];

/// Narrow low-end phone (DS §7 reference width).
const matrixPhone = Size(360, 780);

/// Registers the 4 matrix cases for one component.
///
/// [scroll] wraps the component in a vertical scroll view (vertical space
/// is not the component's concern; horizontal overflow is). [settle]
/// `false` pumps a fixed 2 s instead of `pumpAndSettle` (shimmer loops).
/// [reduced] forces the in-app reduced-motion setting on the first pass.
void componentMatrix(
  String name,
  ComponentBuilder build, {
  ComponentCheck? check,
  bool scroll = true,
  bool settle = true,
  bool? reduced,
  List overrides = const [],
}) {
  for (final locale in matrixLocales) {
    for (final scale in matrixScales) {
      testWidgets('$name · ${locale.languageCode} · ${scale}x', (t) async {
        t.view.physicalSize = matrixPhone;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final l10n = lookupAppLocalizations(locale);

        Future<List<String>> pass({required bool disable}) async {
          final child = build(l10n);
          await pumpMotion(
            t,
            scroll ? SingleChildScrollView(child: child) : child,
            locale: locale,
            textScale: scale,
            disableAnimations: disable,
            reduced: disable ? null : reduced,
            overrides: overrides,
          );
          await _settle(t, settle);
          expect(t.takeException(), isNull, reason: 'no overflow / error');
          if (check != null) await check(t, l10n);
          await _settle(t, settle);
          expect(t.takeException(), isNull, reason: 'no error after check');
          return renderedTexts(t);
        }

        final animated = await pass(disable: false);
        await t.pumpWidget(const SizedBox.shrink());
        final still = await pass(disable: true);
        expect(still, animated, reason: 'same text with and without motion');
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(seconds: 5));
      });
    }
  }
}

Future<void> _settle(WidgetTester t, bool settle) async {
  if (settle) {
    await t.pumpAndSettle();
  } else {
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
  }
}

/// Plain text of every `RichText` and editable field on screen, in tree
/// order (icons included as their glyph code points).
List<String> renderedTexts(WidgetTester t) => [
  for (final r in t.widgetList<RichText>(find.byType(RichText)))
    r.text.toPlainText(),
  for (final e in t.widgetList<EditableText>(find.byType(EditableText)))
    e.controller.text,
];

/// Asserts a semantics node with exactly [label] exists.
void expectSemantics(String label) =>
    expect(find.bySemanticsLabel(label), findsWidgets, reason: label);

/// Asserts a semantics node whose label contains [part] exists.
void expectSemanticsContaining(String part) => expect(
  find.bySemanticsLabel(RegExp(RegExp.escape(part))),
  findsWidgets,
  reason: part,
);
