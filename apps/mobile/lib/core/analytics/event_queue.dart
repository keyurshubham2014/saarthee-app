import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/app_error.dart';
import '../settings/app_settings.dart';

/// App-sent analytics event names (03 §11). Properties must never contain
/// phone numbers, tokens, invite codes, coordinates or notes.
class AppEvents {
  const AppEvents._();

  static const inviteCodeEntered = 'invite_code_entered';
  static const reportOpened = 'report_opened';
  static const ccrsHandoffClicked = 'ccrs_handoff_clicked';
  static const deepLinkFailed = 'deep_link_failed';
}

/// Persisted, capped queue flushed to POST /events (02 §7):
/// at 20 queued, when the app goes to the background, and every 60 s.
/// Capped at 500 (oldest dropped); a 429 drops the batch; network errors
/// keep it for later.
class EventQueue with WidgetsBindingObserver {
  EventQueue(this._ref) {
    _load();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(flushInterval, (_) => flush());
  }

  static const int flushAt = 20;
  static const int cap = 500;
  static const int batchMax = 50;
  static const Duration flushInterval = Duration(seconds: 60);
  static const _kQueue = 'eventQueue';

  final Ref _ref;
  final List<Map<String, dynamic>> _items = [];
  Timer? _timer;
  bool _flushing = false;

  int get length => _items.length;

  void _load() {
    final raw = _ref.read(sharedPreferencesProvider).getString(_kQueue);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        _items.addAll(list.whereType<Map<String, dynamic>>());
      }
    } on FormatException {
      _ref.read(sharedPreferencesProvider).remove(_kQueue);
    }
  }

  Future<void> _save() => _ref
      .read(sharedPreferencesProvider)
      .setString(_kQueue, jsonEncode(_items));

  void track(String name, [Map<String, Object?> properties = const {}]) {
    _items.add({
      'name': name,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      if (properties.isNotEmpty) 'properties': properties,
    });
    while (_items.length > cap) {
      _items.removeAt(0);
    }
    _save();
    if (_items.length >= flushAt) flush();
  }

  Future<void> flush() async {
    if (_flushing || _items.isEmpty) return;
    _flushing = true;
    try {
      while (_items.isNotEmpty) {
        final batch = _items.take(batchMax).toList();
        try {
          await _ref
              .read(apiClientProvider)
              .postJson('/events', body: {'events': batch});
          _items.removeRange(0, batch.length);
        } on AppError catch (e) {
          if (e.isOffline) break; // keep for later
          // 429 or any rejection: drop the batch rather than retry forever.
          _items.removeRange(0, batch.length);
        }
      }
      await _save();
    } finally {
      _flushing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      flush();
    }
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

final eventQueueProvider = Provider<EventQueue>((ref) {
  final q = EventQueue(ref);
  ref.onDispose(q.dispose);
  return q;
});
