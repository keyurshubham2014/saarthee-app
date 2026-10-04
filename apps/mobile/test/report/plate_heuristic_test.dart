// W-05-13 (AC-11, REQ-S-007): Indian number-plate heuristic over recognised
// text blocks.
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/capture/blur/face_plate_detector.dart';

void main() {
  group('registration format (normalisePlate)', () {
    const positives = {
      'GJ 01 AB 1234': 'GJ01AB1234',
      'GJ01AB1234': 'GJ01AB1234',
      'gj 01 ab 1234': 'GJ01AB1234',
      'GJ-01-AB-1234': 'GJ01AB1234',
      'GJ 1 AB 1234': 'GJ1AB1234',
      'MH 12 1234': 'MH121234',
      'MH 12 DE 1433': 'MH12DE1433',
      'DL 3C AB 1234': 'DL3CAB1234',
      'KA 05 MN 123': 'KA05MN123',
      'TN 09 BY 9726': 'TN09BY9726',
      'GJ 27 C 4567': 'GJ27C4567',
      'GJ01AB\n1234': 'GJ01AB1234', // two-line plate in one block
      // OCR confusions fixed by position.
      'GJ O1 AB 1234': 'GJ01AB1234',
      'GJ 0I AB I234': 'GJ01AB1234',
      'G1 01 AB 1234': 'GI01AB1234',
      'GJ 01 A0 1234': 'GJ01AO1234',
      'GJ 01 AB 12O4': 'GJ01AB1204',
      '22 BH 1234 AA': '22BH1234AA',
      '22 8H 1234 A': '22BH1234A',
    };
    for (final e in positives.entries) {
      test('plate: ${e.key.replaceAll('\n', r'\n')}', () {
        expect(normalisePlate(e.key), e.value);
      });
    }

    const negatives = [
      'SHOP OPEN',
      '155303',
      '9876543210', // phone number
      'AMC 2026',
      'NO PARKING',
      'GJ 01', // too short
      'GJ 01 ABCD 1234', // four series letters
      'GJ 123 AB 1234', // three-digit district code
      'AB1234567',
      'WELCOME TO PALDI',
      'GJ 01 AB 12', // number too short
      '',
    ];
    for (final n in negatives) {
      test('not a plate: "$n"', () => expect(normalisePlate(n), isNull));
    }
  });

  group('plate shape (looksLikePlateShape)', () {
    test('short alphanumeric block, plate aspect → plate', () {
      expect(looksLikePlateShape('GJ0l AB 12B4', 4.3), isTrue);
      expect(looksLikePlateShape('GJ01\nAB12', 1.8), isTrue);
    });
    test('wrong aspect, too long, or no digits → not a plate', () {
      expect(looksLikePlateShape('GJ01AB1234', 1.0), isFalse);
      expect(looksLikePlateShape('GJ01AB1234', 9.0), isFalse);
      expect(looksLikePlateShape('MUNICIPAL CORP 2026 WARD 12', 4), isFalse);
      expect(looksLikePlateShape('NO PARKING', 4), isFalse);
      expect(looksLikePlateShape('1234', 4), isFalse);
    });
  });

  test('plateBoxes keeps format matches and plate-shaped blocks', () {
    const plate = BlurBox(0.1, 0.1, 0.2, 0.05);
    const sign = BlurBox(0.5, 0.1, 0.4, 0.1);
    const square = BlurBox(0.1, 0.5, 0.1, 0.13);
    final boxes = plateBoxes([
      const TextBlockBox('GJ 01 AB 1234', square), // format wins
      const TextBlockBox('GJ0l A8 l2B4', plate), // misread, plate shape
      const TextBlockBox('NO PARKING', sign),
      const TextBlockBox('SHOP 24 X', square), // square: not plate shaped
    ], imageAspect: 4 / 3);
    expect(boxes, [square, plate]);
  });
}
