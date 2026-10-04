import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A box to blur, in fractions of the image size (0–1), so the same box works
/// on the full photo and its on-screen preview.
@immutable
class BlurBox {
  const BlurBox(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  /// The box grown by [fraction] of its size on every side, clamped to 0–1.
  BlurBox padded([double fraction = 0.15]) {
    final dx = width * fraction;
    final dy = height * fraction;
    final l = (left - dx).clamp(0.0, 1.0);
    final t = (top - dy).clamp(0.0, 1.0);
    return BlurBox(
      l,
      t,
      (left + width + dx).clamp(0.0, 1.0) - l,
      (top + height + dy).clamp(0.0, 1.0) - t,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BlurBox &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// Pixelates [boxes] of a JPEG with [block]-px blocks (TASK-05 §5.6: 12 px)
/// and re-encodes it (quality 85). Pure function: runs in a background
/// isolate through [renderBlurredFile]; tests call it directly.
Uint8List pixelateJpeg(Uint8List jpeg, List<BlurBox> boxes, {int block = 12}) {
  final decoded = img.decodeJpg(jpeg);
  if (decoded == null) throw const FormatException('not a JPEG');
  final w = decoded.width;
  final h = decoded.height;
  for (final b in boxes) {
    final x0 = (b.left * w).floor().clamp(0, w);
    final y0 = (b.top * h).floor().clamp(0, h);
    final x1 = ((b.left + b.width) * w).ceil().clamp(0, w);
    final y1 = ((b.top + b.height) * h).ceil().clamp(0, h);
    for (var by = y0; by < y1; by += block) {
      for (var bx = x0; bx < x1; bx += block) {
        final ex = (bx + block).clamp(0, x1);
        final ey = (by + block).clamp(0, y1);
        num r = 0, g = 0, bl = 0;
        var n = 0;
        for (var y = by; y < ey; y++) {
          for (var x = bx; x < ex; x++) {
            final p = decoded.getPixel(x, y);
            r += p.r;
            g += p.g;
            bl += p.b;
            n++;
          }
        }
        if (n == 0) continue;
        final c = img.ColorRgb8(r ~/ n, g ~/ n, bl ~/ n);
        for (var y = by; y < ey; y++) {
          for (var x = bx; x < ex; x++) {
            decoded.setPixel(x, y, c);
          }
        }
      }
    }
  }
  return img.encodeJpg(decoded, quality: 85);
}

/// Reads [sourcePath], pixelates [boxes] off the UI thread and writes the
/// result to [targetPath]. With no boxes the file is copied unchanged.
Future<void> renderBlurredFile(
  String sourcePath,
  String targetPath,
  List<BlurBox> boxes,
) async {
  if (boxes.isEmpty) {
    await File(sourcePath).copy(targetPath);
    return;
  }
  final padded = [for (final b in boxes) b.padded()];
  await Isolate.run(() {
    final bytes = File(sourcePath).readAsBytesSync();
    File(targetPath).writeAsBytesSync(pixelateJpeg(bytes, padded));
  });
}
