import 'dart:convert';

import 'json_read.dart';

/// The signed-in operator.
class AdminProfile {
  const AdminProfile({
    required this.id,
    required this.email,
    required this.displayName,
  });

  factory AdminProfile.fromJson(Map<String, dynamic> json) => AdminProfile(
    id: readString(json, 'id'),
    email: readString(json, 'email'),
    displayName: readString(json, 'displayName'),
  );

  final String id;
  final String email;
  final String displayName;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'email': email,
    'displayName': displayName,
  };
}

/// Admin JWT plus its expiry and profile, kept in secure storage.
class AdminSession {
  const AdminSession({
    required this.accessToken,
    required this.expiresAt,
    required this.admin,
  });

  /// Parses the `POST /admin/auth/login` response.
  factory AdminSession.fromLoginJson(Map<String, dynamic> json) {
    final adminJson = json['admin'];
    return AdminSession(
      accessToken: readString(json, 'accessToken'),
      expiresAt:
          readDateOrNull(json, 'expiresAt')?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(hours: 8)),
      admin: AdminProfile.fromJson(
        adminJson is Map<String, dynamic> ? adminJson : <String, dynamic>{},
      ),
    );
  }

  static AdminSession? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      final token = readString(json, 'accessToken');
      final expiresAt = readDateOrNull(json, 'expiresAt');
      final admin = json['admin'];
      if (token.isEmpty ||
          expiresAt == null ||
          admin is! Map<String, dynamic>) {
        return null;
      }
      return AdminSession(
        accessToken: token,
        expiresAt: expiresAt.toUtc(),
        admin: AdminProfile.fromJson(admin),
      );
    } on FormatException {
      return null;
    }
  }

  final String accessToken;
  final DateTime expiresAt;
  final AdminProfile admin;

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt);

  String encode() => jsonEncode(<String, dynamic>{
    'accessToken': accessToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'admin': admin.toJson(),
  });
}
