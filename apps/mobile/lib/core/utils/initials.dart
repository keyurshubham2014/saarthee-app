import 'package:flutter/widgets.dart';

/// Up to two initials from [name], in the script it is written in. Takes the
/// first grapheme cluster of each word, so a Gujarati letter keeps its vowel
/// sign ("કો", not a bare "ક") and nothing splits a conjunct. Words that
/// start with a digit (seat suffixes like "30-A") are skipped.
String initialsOf(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !RegExp(r'^\d').hasMatch(w));
  return words.take(2).map((w) => w.characters.first).join().toUpperCase();
}
