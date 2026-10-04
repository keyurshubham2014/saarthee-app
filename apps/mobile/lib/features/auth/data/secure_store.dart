import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small key-value store for secrets (session JWT, Firebase refresh token).
/// Backed by `flutter_secure_storage`; tests use [MemorySecureStore].
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // Keystore errors (e.g. after a backup restore) → treat as signed out.
      return null;
    }
  }

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }
}

class MemorySecureStore implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

final secureStoreProvider = Provider<SecureStore>(
  (ref) => const FlutterSecureStore(),
);

/// Keys (never logged).
class SecureKeys {
  const SecureKeys._();

  static const sessionToken = 'saarthee.session.accessToken';
  static const sessionExpiresAt = 'saarthee.session.expiresAt';
  static const firebaseRefreshToken = 'saarthee.firebase.refreshToken';
  static const firebaseUid = 'saarthee.firebase.uid';
}
