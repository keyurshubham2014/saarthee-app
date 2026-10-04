import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Foreground push messages (FCM `onMessage` data payloads: `kind`, `refId`,
/// `route`, `notificationId`). The FCM implementation feeds [deliver] once a
/// Firebase project exists (TASK-04 §13); TASK-08's in-app alert banner
/// listens to [messages]. Additive (TASK-08).
class ForegroundPush {
  final StreamController<Map<String, Object?>> _c =
      StreamController<Map<String, Object?>>.broadcast();

  Stream<Map<String, Object?>> get messages => _c.stream;

  void deliver(Map<String, Object?> data) {
    if (!_c.isClosed) _c.add(data);
  }

  Future<void> close() => _c.close();
}

final foregroundPushProvider = Provider<ForegroundPush>((ref) {
  final f = ForegroundPush();
  ref.onDispose(f.close);
  return f;
});
