import 'blur_renderer.dart';

/// Number-plate heuristic over on-device text recognition (REQ-S-007).
///
/// ML Kit has no plate model, so plates are found among recognised Latin
/// text blocks in two ways (TASK-05 §5.6):
///
/// 1. **Registration format.** The block is upper-cased, everything but
///    letters and digits is dropped (spaces, line breaks of two-line plates,
///    `-`, `.`, `·`), then O/0 and I/1 confusions are fixed by position:
///    the two-letter state code and the series letters become letters, the
///    district code and the number become digits. The result must match
///    [kIndianPlate] (`GJ 01 AB 1234`, `MH 12 1234`, `DL 3 CAB 123`) or the
///    Bharat series [kBharatPlate] (`22 BH 1234 AA`).
/// 2. **Plate shape.** A short block (4–12 letters/digits after
///    normalising) with at least one letter and two digits whose box is
///    1.5–6.5 times as wide as it is tall (single-line plates are about
///    4.3:1, two-line and motorcycle plates about 1.7–2:1) is blurred too,
///    because OCR often misreads a character or two on a real plate.
///
/// Blurring a shop sign such as "SHOP 24" by mistake costs nothing; leaving
/// a plate readable is a privacy leak, so the heuristic leans to blurring.
final RegExp kIndianPlate = RegExp(
  r'^[A-Z]{2}\s?\d{1,2}\s?[A-Z]{0,3}\s?\d{3,4}$',
);

/// Bharat (BH) series: year, `BH`, four digits, one or two letters.
final RegExp kBharatPlate = RegExp(r'^\d{2}BH\d{4}[A-Z]{1,2}$');

/// A text block found in a photo (fractions of the image size).
class TextBlockBox {
  const TextBlockBox(this.text, this.box);

  final String text;
  final BlurBox box;
}

/// Letters and digits only, upper case.
String compactPlateText(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

String _asLetters(String s) => s.replaceAll('0', 'O').replaceAll('1', 'I');
String _asDigits(String s) => s.replaceAll('O', '0').replaceAll('I', '1');

/// The plate reading of [raw] with O/0 and I/1 fixed by position, or null
/// when the text is not an Indian registration number.
String? normalisePlate(String raw) {
  final s = compactPlateText(raw);
  if (s.length < 7 || s.length > 11) return null;
  // Bharat series: NN BH NNNN A(A).
  if (s.length >= 9) {
    final bh =
        _asDigits(s.substring(0, 2)) +
        s.substring(2, 4).replaceAll('8', 'B') +
        _asDigits(s.substring(4, 8)) +
        _asLetters(s.substring(8));
    if (kBharatPlate.hasMatch(bh)) return bh;
  }
  final state = _asLetters(s.substring(0, 2));
  // Try a 4- then 3-digit number, and a 1- or 2-digit district code.
  for (final numLen in const [4, 3]) {
    if (s.length - 2 - numLen < 1) continue;
    final number = _asDigits(s.substring(s.length - numLen));
    final middle = s.substring(2, s.length - numLen);
    for (final distLen in const [2, 1]) {
      if (middle.length < distLen || middle.length - distLen > 3) continue;
      final candidate =
          state +
          _asDigits(middle.substring(0, distLen)) +
          _asLetters(middle.substring(distLen)) +
          number;
      if (kIndianPlate.hasMatch(candidate)) return candidate;
    }
  }
  return null;
}

/// True when [text] in a box [pixelAspect] times as wide as tall looks like
/// a plate by shape alone (rule 2 above).
bool looksLikePlateShape(String text, double pixelAspect) {
  final s = compactPlateText(text);
  if (s.length < 4 || s.length > 12) return false;
  final digits = RegExp(r'\d').allMatches(s).length;
  final letters = s.length - digits;
  return letters >= 1 &&
      digits >= 2 &&
      pixelAspect >= 1.5 &&
      pixelAspect <= 6.5;
}

/// Plate boxes among recognised text blocks. [imageAspect] is the photo's
/// width / height, used to turn fractional boxes into a pixel aspect ratio.
List<BlurBox> plateBoxes(
  Iterable<TextBlockBox> blocks, {
  double imageAspect = 4 / 3,
}) => [
  for (final b in blocks)
    if (normalisePlate(b.text) != null ||
        (b.box.height > 0 &&
            looksLikePlateShape(
              b.text,
              b.box.width / b.box.height * imageAspect,
            )))
      b.box,
];
