// W-05-07 (AC-11): the blur renderer pixelates exactly the given boxes; the
// plate heuristic matches Indian plates.
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:saarthee/core/capture/blur/face_plate_detector.dart';

/// 96×96 fixture: a fine checkerboard (every pixel differs from its
/// neighbour), so a pixelated block is easy to tell from the original.
img.Image fixture() {
  final im = img.Image(width: 96, height: 96);
  for (var y = 0; y < 96; y++) {
    for (var x = 0; x < 96; x++) {
      final on = (x + y).isEven;
      im.setPixelRgb(x, y, on ? 240 : 20, on ? 240 : 20, on ? 240 : 20);
    }
  }
  return im;
}

/// Mean absolute difference between horizontally adjacent pixels in a rect.
double roughness(img.Image im, int x0, int y0, int x1, int y1) {
  var sum = 0.0;
  var n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1 - 1; x++) {
      sum += (im.getPixel(x, y).r - im.getPixel(x + 1, y).r).abs();
      n++;
    }
  }
  return sum / n;
}

void main() {
  test('pixelates inside the box (12 px blocks) and leaves the rest', () {
    final src = img.encodeJpg(fixture(), quality: 100);
    // Left half, top half: 48×48 px = 4×4 blocks of 12 px.
    final out = img.decodeJpg(
      pixelateJpeg(src, const [BlurBox(0, 0, 0.5, 0.5)]),
    )!;
    expect(out.width, 96);
    // Inside a block the image is flat (JPEG noise only).
    expect(roughness(out, 2, 2, 10, 10), lessThan(12));
    // Outside the box the checkerboard survives.
    expect(roughness(out, 60, 60, 90, 90), greaterThan(80));
    // Every block averages the two checker colours (≈ 130).
    final mid = out.getPixel(6, 6).r;
    expect(mid, inInclusiveRange(100, 160));
  });

  test('no boxes → image content unchanged', () {
    final src = img.encodeJpg(fixture(), quality: 100);
    final out = img.decodeJpg(pixelateJpeg(src, const []))!;
    expect(roughness(out, 2, 2, 40, 40), greaterThan(80));
  });

  test('padded box grows 15 % per side and stays inside the image', () {
    final p = const BlurBox(0.9, 0.0, 0.2, 0.2).padded();
    expect(p.left, closeTo(0.87, 1e-9));
    expect(p.top, 0);
    expect(p.left + p.width, lessThanOrEqualTo(1));
  });

  test('plate heuristic: Indian plates only', () {
    BlurBox b(double l) => BlurBox(l, 0, 0.1, 0.1);
    final boxes = plateBoxes([
      TextBlockBox('GJ 01 AB 1234', b(0.1)),
      TextBlockBox('gj01ab1234', b(0.2)),
      TextBlockBox('MH 12 1234', b(0.3)),
      TextBlockBox('SHOP OPEN', b(0.4)),
      TextBlockBox('155303', b(0.5)),
    ]);
    expect(boxes, [b(0.1), b(0.2), b(0.3)]);
  });

  test('default detector reports "unavailable" (manual tool only)', () async {
    expect(await const UnavailableDetector().detect('/nope.jpg'), isNull);
  });
}
