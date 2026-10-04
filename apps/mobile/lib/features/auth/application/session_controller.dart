import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/app_error.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/wards/ward_providers.dart';
import '../data/account_api.dart';
import '../data/account_models.dart';
import '../data/auth_gateway.dart';
import '../data/secure_store.dart';
import '../data/session_interceptor.dart';

@immutable
class SessionState {
  const SessionState({this.token, this.me, this.restored = false});

  /// Saarthee session JWT (never shown or logged).
  final String? token;
  final Me? me;

  /// False until the stored session has been read at start-up.
  final bool restored;

  bool get signedIn => token != null;
}

enum ExchangeOutcome { signedIn, needsAge }

/// The citizen session (TASK-04 §5.4): stored in secure storage, attached to
/// API calls by [SessionInterceptor], renewed silently with a fresh Firebase
/// ID token.
class SessionController extends Notifier<SessionState> {
  final Completer<void> _restored = Completer<void>();

  AccountApi get _api => ref.read(accountApiProvider);
  AuthGateway get _gateway => ref.read(authGatewayProvider);
  SecureStore get _store => ref.read(secureStoreProvider);

  @override
  SessionState build() {
    final dio = ref.read(dioProvider);
    if (!dio.interceptors.any((i) => i is SessionInterceptor)) {
      dio.interceptors.add(
        SessionInterceptor(
          dio: dio,
          currentToken: () => state.token,
          renew: renew,
          onSignedOut: clearLocal,
        ),
      );
    }
    unawaited(_restore());
    return const SessionState();
  }

  /// Completes once the stored session has been loaded.
  Future<void> get ready => _restored.future;

  Future<void> _restore() async {
    try {
      final token = await _store.read(SecureKeys.sessionToken);
      state = SessionState(token: token, me: state.me, restored: true);
    } finally {
      if (!_restored.isCompleted) _restored.complete();
    }
  }

  /// `POST /auth/firebase` with the Firebase ID token. A first sign-in without
  /// [ageConfirmed] returns [ExchangeOutcome.needsAge] (nothing is stored).
  Future<ExchangeOutcome> exchange(
    String idToken, {
    bool ageConfirmed = false,
  }) async {
    final ward = ref.read(homeWardProvider);
    try {
      final grant = await _api.exchange(
        idToken: idToken,
        ageConfirmed: ageConfirmed,
        language: ref.read(localeProvider).languageCode,
        homeWardId: ward?.id,
        installId: ref.read(appSettingsProvider).installId,
      );
      await _save(grant);
      return ExchangeOutcome.signedIn;
    } on AppError catch (e) {
      if (e.code == 'AGE_CONFIRMATION_REQUIRED' && !ageConfirmed) {
        return ExchangeOutcome.needsAge;
      }
      rethrow;
    }
  }

  Future<void> _save(SessionGrant grant) async {
    await _store.write(SecureKeys.sessionToken, grant.accessToken);
    await _store.write(
      SecureKeys.sessionExpiresAt,
      grant.expiresAt.toIso8601String(),
    );
    state = SessionState(token: grant.accessToken, me: grant.me, restored: true);
  }

  /// Silent re-exchange after `TOKEN_EXPIRED`; null when not possible.
  Future<String?> renew() async {
    try {
      final idToken = await _gateway.idToken(forceRefresh: true);
      if (idToken == null) return null;
      await exchange(idToken);
      return state.token;
    } catch (_) {
      return null;
    }
  }

  void setMe(Me me) => state = SessionState(
    token: state.token,
    me: me,
    restored: state.restored,
  );

  /// Loads `GET /me` into the session (profile screen).
  Future<Me> refreshMe() async {
    final me = await _api.getMe();
    setMe(me);
    return me;
  }

  /// Signs out of Saarthee (all devices, §5.6) and of Firebase.
  Future<void> signOut() async {
    try {
      await _api.logout(installId: ref.read(appSettingsProvider).installId);
    } catch (_) {
      // Offline or already revoked: the local session is cleared anyway.
    }
    await clearLocal();
  }

  /// `DELETE /me`, then the local session and Firebase user are cleared.
  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await clearLocal();
  }

  /// Forgets the session locally (revoked, deleted, signed out).
  Future<void> clearLocal() async {
    await _store.write(SecureKeys.sessionToken, null);
    await _store.write(SecureKeys.sessionExpiresAt, null);
    await _gateway.signOut();
    state = const SessionState(restored: true);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
