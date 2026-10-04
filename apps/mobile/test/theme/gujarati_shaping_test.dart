// Gujarati text shaped with the `gu` language must draw exactly like the
// script default. Upstream Mukta Vaani's `GUJ ` language system lacked the
// conjunct features, so in the Gujarati UI "પ્રતિનિધિ" drew as "પ્‌રતિનિધિ" and
// "વોર્ડ" lost its reph (fixed by tool/fonts/fix_langsys.py).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _text = 'આ વોર્ડના પ્રતિનિધિઓ તીવ્ર સ્રોત દ્વારા સમસ્યા';

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
    );
  }
  await loader.load();
}

Future<Uint8List> _render(
  WidgetTester t,
  String family,
  FontWeight weight,
  Locale? locale,
) async {
  final key = GlobalKey();
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFFFFFFFF),
            width: 900,
            child: Text(
              _text,
              style: TextStyle(
                fontFamily: family,
                fontWeight: weight,
                fontSize: 28,
                color: const Color(0xFF000000),
                locale: locale,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  late Uint8List bytes;
  await t.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    bytes = data!.buffer.asUint8List();
  });
  return bytes;
}

void main() {
  setUpAll(() async {
    await _load('MuktaVaani', [
      'assets/fonts/MuktaVaani-Regular.ttf',
      'assets/fonts/MuktaVaani-Medium.ttf',
      'assets/fonts/MuktaVaani-SemiBold.ttf',
    ]);
    await _load('BalooBhai2', [
      'assets/fonts/BalooBhai2-SemiBold.ttf',
      'assets/fonts/BalooBhai2-Bold.ttf',
      'assets/fonts/BalooBhai2-ExtraBold.ttf',
    ]);
  });

  for (final (family, weight) in const [
    ('MuktaVaani', FontWeight.w400),
    ('MuktaVaani', FontWeight.w500),
    ('MuktaVaani', FontWeight.w600),
    ('BalooBhai2', FontWeight.w700),
  ]) {
    testWidgets('$family ${weight.value}: gu shaping matches the default', (
      t,
    ) async {
      final plain = await _render(t, family, weight, null);
      final gu = await _render(t, family, weight, const Locale('gu'));
      expect(gu, plain);
    });
  }
}
