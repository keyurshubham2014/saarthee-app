import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Verify token held in memory only for the verify session (02 §3.1). It is
/// never written to disk, logged, placed in a route location or put in an
/// event; it travels only in the `X-Verify-Token` header.
class VerifyTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String token) => state = token;

  void clear() => state = null;
}

final verifyTokenProvider = NotifierProvider<VerifyTokenNotifier, String?>(
  VerifyTokenNotifier.new,
);

/// 32 random bytes, URL-safe base64 without padding (03 §3.2).
final RegExp _tokenFormat = RegExp(r'^[A-Za-z0-9_-]{43}$');

/// `parseVerifyInput` (TASK-07 §5.4): accepts `saarthee://verify?t=X`,
/// `https://<any-host>/verify?t=X`, or a bare token. Returns null when
/// unparseable.
String? parseVerifyInput(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final match = RegExp(r'[?&]t=([^&\s#]+)').firstMatch(text);
  String candidate;
  if (match != null) {
    try {
      candidate = Uri.decodeQueryComponent(match.group(1)!);
    } on ArgumentError {
      return null;
    }
  } else {
    candidate = text;
  }
  return _tokenFormat.hasMatch(candidate) ? candidate : null;
}
