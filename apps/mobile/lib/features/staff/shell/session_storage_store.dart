import '../../auth/data/secure_store.dart';
import 'session_storage_backend_stub.dart'
    if (dart.library.js_interop) 'session_storage_backend_web.dart';

/// Staff web session store (TASK-10 §5.4): memory first, mirrored to the
/// tab's `sessionStorage` so a reload keeps the session; never
/// `localStorage`. Off the web it is memory only.
class SessionStorageStore implements SecureStore {
  SessionStorageStore([SessionBackend? backend]) : _backend = backend ?? SessionBackend();

  final SessionBackend _backend;
  final Map<String, String> _memory = {};

  @override
  Future<String?> read(String key) async => _memory[key] ?? _backend.read(key);

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _memory.remove(key);
      _backend.remove(key);
    } else {
      _memory[key] = value;
      _backend.write(key, value);
    }
  }
}
