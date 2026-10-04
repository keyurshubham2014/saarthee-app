import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Device push boundary (TASK-04 §5.4). The FCM implementation
/// (`firebase_messaging` + `flutter_local_notifications`) is Deferred — needs
/// Firebase project (TASK-04 §13); until then [LocalOnlyPushMessaging] keeps
/// the topic bookkeeping and device registration working without delivery.
abstract interface class PushMessaging {
  /// Whether this build can actually receive pushes.
  bool get delivers;

  /// Asks for the OS permission (Android 13+ `POST_NOTIFICATIONS`). Never
  /// called at first launch — only from the Home soft prompt or Privacy.
  Future<bool> requestPermission();

  /// Current FCM registration token, or null.
  Future<String?> token();

  Future<void> subscribe(String topic);
  Future<void> unsubscribe(String topic);
}

/// No FCM: permission is treated as granted, no token, topic calls recorded.
class LocalOnlyPushMessaging implements PushMessaging {
  final List<String> subscribed = [];
  final List<String> unsubscribed = [];

  @override
  bool get delivers => false;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<String?> token() async => null;

  @override
  Future<void> subscribe(String topic) async => subscribed.add(topic);

  @override
  Future<void> unsubscribe(String topic) async => unsubscribed.add(topic);
}

final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => LocalOnlyPushMessaging(),
);

/// Android notification channels (ids are part of the FCM contract; names
/// come from ARB `accountChannel*`).
enum PushChannel {
  criticalAlerts('critical_alerts'),
  alerts('alerts'),
  updates('updates');

  const PushChannel(this.id);

  final String id;
}

/// FCM topics for a device: `ward_<n>__<lang>` and `city_all__<lang>` (D9 +
/// language suffix, TASK-04 §5.6). No ward → city only.
List<String> pushTopicsFor({required String language, int? wardNumber}) {
  final lang = language == 'en' ? 'en' : 'gu';
  return [
    if (wardNumber != null) 'ward_${wardNumber}__$lang',
    'city_all__$lang',
  ];
}
