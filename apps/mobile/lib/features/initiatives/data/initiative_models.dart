/// Civic initiative models (TASK-12 §5.3).
library;

import '../../services/data/service_models.dart' show pick;

String _s(Object? v) => v == null ? '' : '$v';

class Initiative {
  const Initiative({
    required this.id,
    required this.titleEn,
    required this.titleGu,
    required this.type,
    required this.organiser,
    required this.organiserName,
    required this.locationTextEn,
    required this.locationTextGu,
    required this.startsAt,
    required this.endsAt,
    required this.goingCount,
    required this.status,
    this.wardId,
    this.capacity,
    this.myRsvp,
    this.descriptionEn = '',
    this.descriptionGu = '',
    this.sourceUrl,
    this.lat,
    this.lng,
  });

  final String id;
  final String titleEn;
  final String titleGu;
  final String type;
  final String organiser;
  final String organiserName;
  final String? wardId;
  final String locationTextEn;
  final String locationTextGu;
  final DateTime startsAt;
  final DateTime endsAt;
  final int? capacity;
  final int goingCount;
  final String status;
  final String? myRsvp;
  final String descriptionEn;
  final String descriptionGu;
  final String? sourceUrl;
  final double? lat;
  final double? lng;

  String title(String lang) => pick(lang, titleEn, titleGu);
  String place(String lang) => pick(lang, locationTextEn, locationTextGu);
  String description(String lang) => pick(lang, descriptionEn, descriptionGu);

  bool get isGoing => myRsvp == 'going' || myRsvp == 'attended';
  bool get isCancelled => status == 'cancelled';
  bool isFull() => capacity != null && goingCount >= capacity!;
  bool hasStarted(DateTime now) => !startsAt.isAfter(now);

  Initiative copyWith({
    int? goingCount,
    String? myRsvp,
    bool clearRsvp = false,
  }) => Initiative(
    id: id,
    titleEn: titleEn,
    titleGu: titleGu,
    type: type,
    organiser: organiser,
    organiserName: organiserName,
    wardId: wardId,
    locationTextEn: locationTextEn,
    locationTextGu: locationTextGu,
    startsAt: startsAt,
    endsAt: endsAt,
    capacity: capacity,
    goingCount: goingCount ?? this.goingCount,
    status: status,
    myRsvp: clearRsvp ? null : (myRsvp ?? this.myRsvp),
    descriptionEn: descriptionEn,
    descriptionGu: descriptionGu,
    sourceUrl: sourceUrl,
    lat: lat,
    lng: lng,
  );

  factory Initiative.fromJson(Map<String, dynamic> j) => Initiative(
    id: _s(j['id']),
    titleEn: _s(j['titleEn']),
    titleGu: _s(j['titleGu']),
    type: _s(j['type']),
    organiser: _s(j['organiser']),
    organiserName: _s(j['organiserName']),
    wardId: j['wardId'] as String?,
    locationTextEn: _s(j['locationTextEn']),
    locationTextGu: _s(j['locationTextGu']),
    startsAt: DateTime.parse(_s(j['startsAt'])).toLocal(),
    endsAt: DateTime.parse(_s(j['endsAt'])).toLocal(),
    capacity: (j['capacity'] as num?)?.toInt(),
    goingCount: (j['goingCount'] as num?)?.toInt() ?? 0,
    status: _s(j['status']),
    myRsvp: j['myRsvp'] as String?,
    descriptionEn: _s(j['descriptionEn']),
    descriptionGu: _s(j['descriptionGu']),
    sourceUrl: j['sourceUrl'] as String?,
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titleEn': titleEn,
    'titleGu': titleGu,
    'type': type,
    'organiser': organiser,
    'organiserName': organiserName,
    'wardId': wardId,
    'locationTextEn': locationTextEn,
    'locationTextGu': locationTextGu,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    'capacity': capacity,
    'goingCount': goingCount,
    'status': status,
    'myRsvp': myRsvp,
  };
}

/// Result of POST/DELETE `/initiatives/{id}/rsvp`.
class RsvpResult {
  const RsvpResult({required this.going, required this.goingCount});

  final bool going;
  final int goingCount;

  factory RsvpResult.fromJson(Map<String, dynamic> j) => RsvpResult(
    going: j['status'] == 'going',
    goingCount: (j['goingCount'] as num?)?.toInt() ?? 0,
  );
}
