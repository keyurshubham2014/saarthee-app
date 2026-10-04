import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/widgets/brand.dart';

/// The painter must draw exactly the master geometry in docs/brand/mark.svg.
void main() {
  final svg = File('../../docs/brand/mark.svg').readAsStringSync();

  String tag(String id) =>
      RegExp('<[a-z]+ id="$id"[^>]*>').firstMatch(svg)!.group(0)!;
  double attr(String id, String name) =>
      double.parse(RegExp(' $name="([^"]+)"').firstMatch(tag(id))!.group(1)!);
  List<double> nums(String s) =>
      RegExp(r'-?\d*\.?\d+')
          .allMatches(s)
          .map((m) => double.parse(m.group(0)!))
          .toList();

  group('BrandMarkPainter matches docs/brand/mark.svg', () {
    test('square', () {
      expect(attr('square', 'width'), 100);
      expect(attr('square', 'rx'), BrandMarkPainter.cornerRadius);
      expect(tag('square'), contains('fill="#14674A"'));
    });

    test('route', () {
      final d = RegExp(' d="([^"]+)"').firstMatch(tag('route'))!.group(1)!;
      // M x y L x y Q cx cy x y L x y
      expect(d.replaceAll(RegExp(r'[^A-Z]'), ''), 'MLQL');
      const p = BrandMarkPainter.routeStart;
      const a = BrandMarkPainter.routeTurnStart;
      const c = BrandMarkPainter.routeTurnControl;
      const b = BrandMarkPainter.routeTurnEnd;
      const e = BrandMarkPainter.routeEnd;
      expect(nums(d), [
        p.dx,
        p.dy,
        a.dx,
        a.dy,
        c.dx,
        c.dy,
        b.dx,
        b.dy,
        e.dx,
        e.dy,
      ]);
      expect(attr('route', 'stroke-width'), BrandMarkPainter.routeStroke);
      expect(tag('route'), contains('stroke-linecap="round"'));
    });

    test('dot', () {
      expect(attr('dot', 'cx'), BrandMarkPainter.dotCenter.dx);
      expect(attr('dot', 'cy'), BrandMarkPainter.dotCenter.dy);
      expect(attr('dot', 'r'), BrandMarkPainter.dotRadius);
      expect(tag('dot'), contains('fill="#C24A1F"'));
    });
  });

  for (final size in [16.0, 48.0, 120.0]) {
    testWidgets('BrandMark pumps at $size px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: BrandMark(size: size, semanticLabel: 'Saarthee'),
          ),
        ),
      );
      final box = tester.getSize(find.byType(BrandMark));
      expect(box, Size(size, size));
      expect(find.bySemanticsLabel('Saarthee'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
