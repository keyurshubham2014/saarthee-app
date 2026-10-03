import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/admin_api.dart';
import '../data/admin_api_error.dart';
import '../data/admin_repositories.dart';
import '../data/admin_session_store.dart';
import '../data/models/admin_session.dart';

/// Admin calls share the app's configured dio (base URL, timeouts and
/// standard headers from core); the bearer token is added per call.
final adminDioProvider = Provider<Dio>((ref) => ref.watch(dioProvider));

final adminSessionStoreProvider = Provider<AdminSessionStore>(
  (ref) => AdminSessionStore(),
);

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(
    dio: ref.watch(adminDioProvider),
    readToken: () => ref.read(adminAuthProvider).session?.accessToken,
    onSessionEnded: () =>
        ref.read(adminAuthProvider.notifier).handleUnauthorized(),
  );
});

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>(
  (ref) => AdminAuthRepository(ref.watch(adminApiProvider)),
);

final adminComplaintsRepositoryProvider = Provider<AdminComplaintsRepository>(
  (ref) => AdminComplaintsRepository(ref.watch(adminApiProvider)),
);

final adminRatesRepositoryProvider = Provider<AdminRatesRepository>(
  (ref) => AdminRatesRepository(ref.watch(adminApiProvider)),
);

final adminReferenceRepositoryProvider = Provider<AdminReferenceRepository>(
  (ref) => AdminReferenceRepository(ref.watch(adminApiProvider)),
);

enum AdminAuthStatus { unknown, signedOut, signedIn }

class AdminAuthState {
  const AdminAuthState({
    required this.status,
    this.session,
    this.sessionEnded = false,
  });

  const AdminAuthState.unknown() : this(status: AdminAuthStatus.unknown);

  final AdminAuthStatus status;
  final AdminSession? session;

  /// True after a 401/expiry so the login screen can say
  /// "Your session ended. Please log in again."
  final bool sessionEnded;

  bool get isSignedIn => status == AdminAuthStatus.signedIn && session != null;
}

/// `adminAuthProvider` (02 §5.2): JWT, expiry and profile in secure storage.
final adminAuthProvider = NotifierProvider<AdminAuthController, AdminAuthState>(
  AdminAuthController.new,
);

class AdminAuthController extends Notifier<AdminAuthState> {
  Future<void>? _restoring;

  @override
  AdminAuthState build() {
    unawaited(ensureRestored());
    return const AdminAuthState.unknown();
  }

  AdminSessionStore get _store => ref.read(adminSessionStoreProvider);

  /// Loads a stored session once; expired sessions are dropped.
  Future<void> ensureRestored() => _restoring ??= _restore();

  Future<void> _restore() async {
    final stored = await _store.read();
    if (!ref.mounted || state.status != AdminAuthStatus.unknown) {
      return;
    }
    if (stored == null) {
      state = const AdminAuthState(status: AdminAuthStatus.signedOut);
    } else if (stored.isExpiredAt(DateTime.now())) {
      await _store.clear();
      state = const AdminAuthState(
        status: AdminAuthStatus.signedOut,
        sessionEnded: true,
      );
    } else {
      state = AdminAuthState(status: AdminAuthStatus.signedIn, session: stored);
    }
  }

  /// Signs in. Throws [AdminApiError] on failure.
  Future<void> login({required String email, required String password}) async {
    final session = await ref
        .read(adminAuthRepositoryProvider)
        .login(email: email, password: password);
    await _store.write(session);
    state = AdminAuthState(status: AdminAuthStatus.signedIn, session: session);
  }

  /// "Log out" on this device only.
  Future<void> logout() async {
    await _store.clear();
    state = const AdminAuthState(status: AdminAuthStatus.signedOut);
  }

  /// "Log out everywhere": bumps `token_version` on the server, then clears
  /// the local token. Throws [AdminApiError] (except for ended sessions).
  Future<void> logoutEverywhere() async {
    try {
      await ref.read(adminAuthRepositoryProvider).logoutAll();
    } on AdminApiError catch (e) {
      if (!e.isSessionEnded && e.statusCode != 401) {
        rethrow;
      }
    }
    await logout();
  }

  /// 401 `TOKEN_EXPIRED` / `TOKEN_REVOKED`, or local expiry.
  void handleUnauthorized() {
    if (state.status == AdminAuthStatus.signedOut) {
      return;
    }
    unawaited(_store.clear());
    state = const AdminAuthState(
      status: AdminAuthStatus.signedOut,
      sessionEnded: true,
    );
  }

  /// Returns to login when the stored expiry has passed.
  void checkExpiry() {
    final session = state.session;
    if (session != null && session.isExpiredAt(DateTime.now())) {
      handleUnauthorized();
    }
  }

  /// Clears the "session ended" banner once shown and acted on.
  void acknowledgeSessionEnded() {
    if (state.sessionEnded) {
      state = AdminAuthState(status: state.status, session: state.session);
    }
  }
}

/// Login form state: in-flight flag and the last error.
class AdminLoginState {
  const AdminLoginState({this.submitting = false, this.error});
  final bool submitting;
  final AdminApiError? error;
}

final adminLoginProvider =
    NotifierProvider.autoDispose<AdminLoginController, AdminLoginState>(
      AdminLoginController.new,
    );

class AdminLoginController extends Notifier<AdminLoginState> {
  @override
  AdminLoginState build() => const AdminLoginState();

  /// Returns true on success. Double submits are ignored.
  Future<bool> submit({required String email, required String password}) async {
    if (state.submitting) {
      return false;
    }
    state = const AdminLoginState(submitting: true);
    try {
      await ref
          .read(adminAuthProvider.notifier)
          .login(email: email, password: password);
      if (ref.mounted) {
        state = const AdminLoginState();
      }
      return true;
    } on AdminApiError catch (e) {
      if (ref.mounted) {
        state = AdminLoginState(error: e);
      }
      return false;
    }
  }
}
