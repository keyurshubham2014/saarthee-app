import 'package:flutter/foundation.dart';

/// Consent purposes (Spec §11, API `consent_purpose`).
enum ConsentPurpose {
  coreService('core_service'),
  shareWithRepresentatives('share_with_representatives'),
  shareWithAmcHandoff('share_with_amc_handoff'),
  notifications('notifications');

  const ConsentPurpose(this.wire);

  final String wire;

  static ConsentPurpose? fromWire(Object? v) {
    for (final p in values) {
      if (p.wire == v) return p;
    }
    return null;
  }
}

/// Current consent text version (TASK-04 §5.6; legal review pending).
const String kConsentTextVersion = 'v2-1';

@immutable
class MeConsent {
  const MeConsent({
    required this.purpose,
    required this.granted,
    required this.textVersion,
  });

  final ConsentPurpose purpose;
  final bool granted;
  final String textVersion;
}

@immutable
class HomeWardRef {
  const HomeWardRef({required this.id, this.number, this.nameEn, this.nameGu});

  final String id;
  final int? number;
  final String? nameEn;
  final String? nameGu;
}

/// `GET /me` (TASK-04 §5.3). The phone is only ever masked.
@immutable
class Me {
  const Me({
    required this.id,
    required this.displayName,
    required this.phoneMasked,
    required this.language,
    required this.role,
    required this.homeWard,
    required this.consents,
  });

  final String id;
  final String? displayName;
  final String? phoneMasked;
  final String language;
  final String role;
  final HomeWardRef? homeWard;
  final List<MeConsent> consents;

  bool consentGranted(ConsentPurpose p) =>
      consents.any((c) => c.purpose == p && c.granted);

  Me copyWith({List<MeConsent>? consents}) => Me(
    id: id,
    displayName: displayName,
    phoneMasked: phoneMasked,
    language: language,
    role: role,
    homeWard: homeWard,
    consents: consents ?? this.consents,
  );

  static List<MeConsent> consentsFromJson(Object? raw) => [
    for (final c in (raw as List? ?? const []).whereType<Map>())
      if (ConsentPurpose.fromWire(c['purpose']) case final p?)
        MeConsent(
          purpose: p,
          granted: c['granted'] == true,
          textVersion: '${c['textVersion'] ?? ''}',
        ),
  ];

  factory Me.fromJson(Map<String, dynamic> j) {
    final w = j['homeWard'];
    return Me(
      id: '${j['id']}',
      displayName: j['displayName'] as String?,
      phoneMasked: j['phoneMasked'] as String?,
      language: j['language'] == 'en' ? 'en' : 'gu',
      role: '${j['role'] ?? 'citizen'}',
      homeWard: w is Map
          ? HomeWardRef(
              id: '${w['id']}',
              number: (w['number'] as num?)?.toInt(),
              nameEn: w['nameEn'] as String?,
              nameGu: w['nameGu'] as String?,
            )
          : null,
      consents: consentsFromJson(j['consents']),
    );
  }
}

/// `POST /auth/firebase` result.
@immutable
class SessionGrant {
  const SessionGrant({
    required this.accessToken,
    required this.expiresAt,
    required this.me,
    required this.isNew,
  });

  final String accessToken;
  final DateTime expiresAt;
  final Me me;
  final bool isNew;

  factory SessionGrant.fromJson(Map<String, dynamic> j) => SessionGrant(
    accessToken: '${j['accessToken']}',
    expiresAt: DateTime.tryParse('${j['expiresAt']}') ?? DateTime.now(),
    me: Me.fromJson((j['user'] as Map).cast<String, dynamic>()),
    isNew: j['isNew'] == true,
  );
}
