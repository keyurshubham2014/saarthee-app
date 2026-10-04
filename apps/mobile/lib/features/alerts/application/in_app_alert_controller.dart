import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/foreground_push.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/tokens.dart';
import '../data/alert_models.dart';
import '../data/alerts_api.dart';

/// What the in-app banner shows.
class InAppAlert {
  const InAppAlert({
    required this.id,
    required this.severity,
    required this.title,
  });

  final String id;
  final AlertSeverity severity;
  final String title;

  bool get critical => severity == AlertSeverity.critical;
}

/// Feeds the in-app alert banner (REQ-F-065): foreground `kind: alert`
/// pushes and new ids in the active alerts list. One banner at a time; a
/// newer one replaces it, but a Critical banner is never replaced by a
/// non-critical one.
class InAppAlertController extends Notifier<InAppAlert?> {
  final Set<String> _seen = {};
  bool _seeded = false;

  @override
  InAppAlert? build() {
    final sub = ref
        .read(foregroundPushProvider)
        .messages
        .listen((data) => unawaited(_onPush(data)));
    ref.onDispose(sub.cancel);
    return null;
  }

  String get _lang => ref.read(localeProvider).languageCode;

  Future<void> _onPush(Map<String, Object?> data) async {
    final id = data['refId'];
    if (data['kind'] != 'alert' || id is! String || id.isEmpty) return;
    try {
      final alert = Alert.fromJson(
        await ref.read(alertsApiProvider).detailRaw(id),
      );
      if (alert.isActive) offer(alert);
    } catch (_) {
      // Offline or gone: the OS notification still exists.
    }
  }

  /// Called after each successful active-list load. The first load only
  /// records ids; later loads show a banner for an unseen alert.
  void onActiveList(List<Alert> items) {
    final fresh = items.where((a) => !_seen.contains(a.id)).toList();
    _seen.addAll(items.map((a) => a.id));
    if (!_seeded) {
      _seeded = true;
      return;
    }
    if (fresh.isEmpty) return;
    fresh.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    offer(fresh.first);
  }

  void offer(Alert a) {
    _seen.add(a.id);
    final next = InAppAlert(
      id: a.id,
      severity: a.severity,
      title: a.title(_lang),
    );
    final current = state;
    if (current != null && current.critical && !next.critical) return;
    state = next;
  }

  /// The banner finished leaving (dismissed, timed out or opened).
  void clear(String id) {
    if (state?.id == id) state = null;
  }
}

final inAppAlertProvider = NotifierProvider<InAppAlertController, InAppAlert?>(
  InAppAlertController.new,
);
