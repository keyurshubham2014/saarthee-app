// Lists ARB keys of lib/core/l10n/app_en.arb that are not referenced in
// lib/ (TASK-03 key retention rule). Run from apps/mobile:
//   dart run tool/l10n/unused_keys.dart          # list
//   dart run tool/l10n/unused_keys.dart --delete # also remove from en + gu
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  const arbDir = 'lib/core/l10n';
  final en = File('$arbDir/app_en.arb');
  final map = jsonDecode(en.readAsStringSync()) as Map<String, dynamic>;
  final buffer = StringBuffer();
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is File &&
        f.path.endsWith('.dart') &&
        !f.path.contains('l10n/app_localizations')) {
      buffer.writeln(f.readAsStringSync());
    }
  }
  final source = buffer.toString();
  final unused = [
    for (final k in map.keys)
      if (!k.startsWith('@') && !RegExp('\\b$k\\b').hasMatch(source)) k,
  ];
  for (final k in unused) {
    stdout.writeln(k);
  }
  stdout.writeln('${unused.length} unused key(s)');
  if (args.contains('--delete') && unused.isNotEmpty) {
    for (final name in ['app_en.arb', 'app_gu.arb']) {
      final file = File('$arbDir/$name');
      if (!file.existsSync()) continue;
      final m = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final k in unused) {
        m
          ..remove(k)
          ..remove('@$k');
      }
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(m)}\n',
      );
    }
  }
}
