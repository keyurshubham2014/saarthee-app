import 'dart:io';

/// A rule violation found by a source scan: `file:line  text`.
class SourceHit {
  SourceHit(this.file, this.line, this.text);
  final String file;
  final int line;
  final String text;

  @override
  String toString() => '$file:$line  ${text.trim()}';
}

/// Dart files under [root] (recursive), skipping generated l10n output and
/// any path that starts with one of [exclude].
List<File> dartFiles(String root, {List<String> exclude = const []}) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  return [
    for (final e in dir.listSync(recursive: true))
      if (e is File &&
          e.path.endsWith('.dart') &&
          !e.path.contains('l10n/app_localizations') &&
          !exclude.any((x) => e.path.startsWith(x)))
        e,
  ]..sort((a, b) => a.path.compareTo(b.path));
}

/// Strips `//` line comments so doc text never trips a guard.
String stripLineComment(String line) {
  final i = line.indexOf('//');
  return i < 0 ? line : line.substring(0, i);
}

/// Scans [source] (named [name]) line by line with [matches].
List<SourceHit> scanSource(
  String name,
  String source,
  bool Function(String code) matches,
) {
  final hits = <SourceHit>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final code = stripLineComment(lines[i]);
    if (matches(code)) hits.add(SourceHit(name, i + 1, lines[i]));
  }
  return hits;
}

/// Scans every file in [files] with [matches].
List<SourceHit> scanFiles(
  List<File> files,
  bool Function(String code) matches,
) => [
  for (final f in files) ...scanSource(f.path, f.readAsStringSync(), matches),
];

// ---- Rules -----------------------------------------------------------------

final _colorLiteral = RegExp(
  r'Color\(0x|(^|[^A-Za-z_])Colors\.(?!transparent)',
);
final _fontSize = RegExp(r'\bfontSize\s*:');
final _materialIcons = RegExp(r'(^|[^A-Za-z_])Icons\.');
final _v1Tokens = RegExp(
  r'\b(ink|inkMuted|indigo\w*|marigold\w*|secondaryContainer|onSecondaryContainer)\b',
);

/// T-03-03: colour, font-size, `Icons.` or v1 / Civic Blue token names.
bool hasStyleLiteral(String code) =>
    _colorLiteral.hasMatch(code) ||
    _fontSize.hasMatch(code) ||
    _materialIcons.hasMatch(code) ||
    _v1Tokens.hasMatch(code);

final _motionLiteral = RegExp(r'\bDuration\(|\bCubic\(|\bCurves\.');

/// T-03-22: motion literals that must come from `SaartheeMotion`/`AppTimings`.
bool hasMotionLiteral(String code) => _motionLiteral.hasMatch(code);

final _textLiteral = RegExp(
  r'''(?:\bText\(\s*|\b(?:label|tooltip|semanticLabel|hintText|labelText|title)\s*:\s*)(['"])(.*?)\1''',
);
final _interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');
final _letter = RegExp('[A-Za-z઀-૿]');

/// T-03-18: a user-facing string literal containing letters (interpolated
/// values alone, such as `'${l10n.x}. ${l10n.y}'`, are allowed).
bool hasHardcodedString(String code) {
  for (final m in _textLiteral.allMatches(code)) {
    final literal = m.group(2)!.replaceAll(_interpolation, '');
    if (_letter.hasMatch(literal)) return true;
  }
  return false;
}
