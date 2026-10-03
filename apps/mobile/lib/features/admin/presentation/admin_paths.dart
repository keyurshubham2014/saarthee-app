/// Admin route paths (02 §3.1).
abstract final class AdminPaths {
  static const login = '/admin/login';
  static const due = '/admin';
  static const complaints = '/admin/complaints';
  static const rates = '/admin/rates';
  static const more = '/admin/more';
  static const inviteCodes = '/admin/invite-codes';
  static const categories = '/admin/categories';
  static const export = '/admin/export';

  static String complaint(String id) =>
      '/admin/complaints/${Uri.encodeComponent(id)}';

  /// Login URL that returns to [from] afterwards.
  static String loginReturningTo(String from) => Uri(
    path: login,
    queryParameters: <String, String>{'from': from},
  ).toString();
}

/// Only admin routes (never the login page itself, never external URLs) are
/// accepted as a return target.
String safeAdminReturnPath(String? from) {
  if (from == null || from.isEmpty) {
    return AdminPaths.due;
  }
  final uri = Uri.tryParse(from);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !(uri.path == AdminPaths.due || uri.path.startsWith('/admin/')) ||
      uri.path == AdminPaths.login) {
    return AdminPaths.due;
  }
  return from;
}
