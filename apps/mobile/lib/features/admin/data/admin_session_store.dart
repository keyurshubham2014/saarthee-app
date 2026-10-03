import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/admin_session.dart';

/// Keeps the admin session (JWT, expiry, profile) in platform secure storage
/// (Android Keystore / iOS Keychain). Never in shared_preferences.
class AdminSessionStore {
  AdminSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'saarthee.admin.session';

  final FlutterSecureStorage _storage;

  Future<AdminSession?> read() async {
    try {
      return AdminSession.tryDecode(await _storage.read(key: _key));
    } on Exception {
      // Unreadable secure storage counts as signed out.
      return null;
    }
  }

  Future<void> write(AdminSession session) =>
      _storage.write(key: _key, value: session.encode());

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Exception {
      // Nothing to clear.
    }
  }
}
