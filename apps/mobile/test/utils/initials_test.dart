import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/utils/initials.dart';

void main() {
  test('initials keep Gujarati vowel signs and skip seat numbers', () {
    expect(initialsOf('Sample Corporator 30-A'), 'SC');
    expect(initialsOf('નમૂના કોર્પોરેટર 30-ક'), 'નકો');
    expect(initialsOf('  ક્ષમા  '), 'ક્ષ');
    expect(initialsOf('ila shah'), 'IS');
    expect(initialsOf(''), '');
  });
}
