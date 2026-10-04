/// Non-web backend: nothing persists beyond memory.
class SessionBackend {
  String? read(String key) => null;
  void write(String key, String value) {}
  void remove(String key) {}
}
