import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/app_error.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/data/secure_store.dart';

/// `GET /staff/me` (TASK-10 §5.3).
class StaffMe {
  const StaffMe({
    required this.actorId,
    required this.actorKind,
    required this.role,
    required this.displayName,
    required this.wardIds,
    required this.nav,
  });

  factory StaffMe.fromJson(Map<String, dynamic> j) => StaffMe(
    actorId: '${j['actorId']}',
    actorKind: '${j['actorKind'] ?? 'user'}',
    role: '${j['role']}',
    displayName: j['displayName'] as String?,
    wardIds: [for (final w in (j['wardIds'] as List? ?? const [])) '$w'],
    nav: [for (final n in (j['nav'] as List? ?? const [])) '$n'],
  );

  final String actorId;

  /// `user` (phone sign-in) or `admin_user` (v1 email admin sign-in).
  final String actorKind;
  final String role;
  final String? displayName;
  final List<String> wardIds;
  final List<String> nav;

  bool get isAdmin => role == 'admin';
}

/// Staff email sign-in (the v1 admin email/password login kept by Spec §7):
/// the admin JWT lives in [SecureStore] — on the staff web build that store
/// is memory + `sessionStorage` (never `localStorage`) — for at most 12 h.
class StaffEmailSession extends Notifier<String?> {
  static const tokenKey = 'saarthee.staff.adminToken';
  static const expiryKey = 'saarthee.staff.adminTokenExpiry';
  /// 12 h in milliseconds (no `Duration` literals in features).
  static const maxAgeMs = 12 * 60 * 60 * 1000;

  @override
  String? build() {
    _restore();
    return null;
  }

  SecureStore get _store => ref.read(secureStoreProvider);

  Future<void> _restore() async {
    final token = await _store.read(tokenKey);
    final expiry = DateTime.tryParse(await _store.read(expiryKey) ?? '');
    if (token == null || expiry == null || expiry.isBefore(DateTime.now())) {
      await _clear();
      return;
    }
    state = token;
  }

  Future<void> _clear() async {
    await _store.write(tokenKey, null);
    await _store.write(expiryKey, null);
    state = null;
  }

  /// Throws [AppError] (INVALID_CREDENTIALS, ADMIN_DISABLED, network).
  Future<void> signIn(String email, String password) async {
    final res = await ref
        .read(apiClientProvider)
        .postJson(
          '/admin/auth/login',
          body: {'email': email.trim(), 'password': password},
        );
    final token = res['accessToken'] as String;
    final serverExpiry = DateTime.tryParse('${res['expiresAt']}');
    final cap = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch + maxAgeMs,
    );
    final expiry = serverExpiry != null && serverExpiry.isBefore(cap)
        ? serverExpiry
        : cap;
    await _store.write(tokenKey, token);
    await _store.write(expiryKey, expiry.toIso8601String());
    state = token;
  }

  Future<void> signOut() => _clear();
}

final staffEmailSessionProvider = NotifierProvider<StaffEmailSession, String?>(
  StaffEmailSession.new,
);

/// Explicit `Authorization` for staff calls made with the email session (the
/// citizen session interceptor adds the phone session token otherwise).
final staffAuthHeadersProvider = Provider<Map<String, String>?>((ref) {
  final phone = ref.watch(sessionProvider.select((s) => s.token));
  if (phone != null) return null;
  final email = ref.watch(staffEmailSessionProvider);
  return email == null ? null : {'Authorization': 'Bearer $email'};
});

/// Why `/staff/me` failed: not signed in, not staff, suspended, or network.
enum StaffAccess { signedOut, notStaff, suspended, error }

class StaffAccessException implements Exception {
  const StaffAccessException(this.access);
  final StaffAccess access;
}

/// The signed-in staff identity; throws [StaffAccessException].
final staffMeProvider = FutureProvider<StaffMe>((ref) async {
  final headers = ref.watch(staffAuthHeadersProvider);
  final phone = ref.watch(sessionProvider.select((s) => s.token));
  if (headers == null && phone == null) {
    throw const StaffAccessException(StaffAccess.signedOut);
  }
  try {
    final j = await ref
        .read(apiClientProvider)
        .getJson('/staff/me', headers: headers);
    return StaffMe.fromJson(j);
  } on AppError catch (e) {
    throw StaffAccessException(switch (e.code) {
      'ACCOUNT_SUSPENDED' => StaffAccess.suspended,
      'FORBIDDEN' => StaffAccess.notStaff,
      'AUTH_REQUIRED' || 'TOKEN_REVOKED' || 'TOKEN_EXPIRED' =>
        StaffAccess.signedOut,
      _ => StaffAccess.error,
    });
  }
});

/// Signs out of both staff sessions.
Future<void> staffSignOut(WidgetRef ref) async {
  await ref.read(staffEmailSessionProvider.notifier).signOut();
  if (ref.read(sessionProvider).signedIn) {
    await ref.read(sessionProvider.notifier).signOut();
  }
  ref.invalidate(staffMeProvider);
}
