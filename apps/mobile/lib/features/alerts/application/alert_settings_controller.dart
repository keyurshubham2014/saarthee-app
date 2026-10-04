import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import '../../../core/push/push_registrar.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/wards/ward_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/alert_models.dart';
import '../data/alerts_api.dart';

/// Max extra wards (API cap, REQ-F-039).
const maxExtraWards = 5;

/// Alert settings (REQ-F-039): signed in → `/me/subscriptions`, visitor →
/// `/devices/{installId}/subscriptions`. Kept locally too, so the screen works
/// offline; an offline save stays pending and is retried by [syncPending].
class AlertSettingsController extends AsyncNotifier<AlertSubscriptions> {
  static const localKey = 'saarthee.alerts.subscriptions';
  static const pendingKey = 'saarthee.alerts.subscriptionsPending';

  AlertsApi get _api => ref.read(alertsApiProvider);

  bool get _signedIn => ref.read(sessionProvider).signedIn;
  String get _installId => ref.read(appSettingsProvider).installId;

  AlertSubscriptions? _local() {
    final raw = ref.read(sharedPreferencesProvider).getString(localKey);
    if (raw == null) return null;
    try {
      return AlertSubscriptions.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _store(AlertSubscriptions s, {required bool pending}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(localKey, jsonEncode(s.toJson()));
    await prefs.setBool(pendingKey, pending);
  }

  @override
  Future<AlertSubscriptions> build() async {
    ref.watch(sessionProvider.select((s) => s.signedIn));
    final local = _local();
    try {
      final remote = _signedIn
          ? await _api.mySubscriptions()
          : await _api.deviceSubscriptions(_installId);
      await _store(remote, pending: false);
      return remote;
    } catch (e) {
      if (local != null) return local;
      if (AppError.from(e).isOffline || !_signedIn) {
        return const AlertSubscriptions();
      }
      rethrow;
    }
  }

  /// Saves [next]. Validation errors and server failures revert and rethrow
  /// (the screen shows "Couldn't save. Try again."); offline keeps it pending.
  Future<void> save(AlertSubscriptions next) async {
    final previous = state.value ?? const AlertSubscriptions();
    if (next.extraWardIds.length > maxExtraWards) {
      throw const AppError(code: 'VALIDATION_FAILED');
    }
    state = AsyncData(next);
    try {
      final saved = await _put(next);
      state = AsyncData(saved);
      await _store(saved, pending: false);
      await ref.read(pushRegistrarProvider).setAlertBaseTopics(saved.topics);
    } catch (e) {
      if (AppError.from(e).isOffline) {
        await _store(next, pending: true);
        return;
      }
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<AlertSubscriptions> _put(AlertSubscriptions s) => _signedIn
      ? _api.putMySubscriptions(s)
      : _api.putDeviceSubscriptions(
          _installId,
          ref.read(homeWardProvider)?.id,
          s,
        );

  /// Re-sends a save made offline (call on reconnect).
  Future<void> syncPending() async {
    if (ref.read(sharedPreferencesProvider).getBool(pendingKey) != true) return;
    final local = _local();
    if (local != null) await save(local);
  }
}

final alertSettingsProvider =
    AsyncNotifierProvider<AlertSettingsController, AlertSubscriptions>(
      AlertSettingsController.new,
    );
