import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Verify token held in memory only for the verify session (02 §3.1). It is
/// never written to disk, logged, or placed in a route location; it travels
/// only in the `X-Verify-Token` header.
class VerifyTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String token) => state = token;

  void clear() => state = null;
}

final verifyTokenProvider = NotifierProvider<VerifyTokenNotifier, String?>(
  VerifyTokenNotifier.new,
);

final RegExp _tokenChars = RegExp(r'^[A-Za-z0-9_-]{8,256}$');

/// Accepts a whole pasted link (`saarthee://verify?t=…` or an https link
/// with `t=`) or just the code part (02 §4.12). Returns null if unusable.
String? extractVerifyToken(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final match = RegExp(r'[?&]t=([^&\s#]+)').firstMatch(text);
  final candidate = match != null
      ? Uri.decodeQueryComponent(match.group(1)!)
      : text;
  return _tokenChars.hasMatch(candidate) ? candidate : null;
}
