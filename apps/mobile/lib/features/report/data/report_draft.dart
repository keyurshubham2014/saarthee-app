/// Local report draft (02 §5.2). Persisted as JSON on every change.
class ReportDraft {
  const ReportDraft({
    required this.clientSubmissionId,
    this.categoryId,
    this.categoryName,
    this.ccrsNumber,
    this.photoPath,
    this.photoId,
    this.latitude,
    this.longitude,
    this.gpsAccuracyM,
    this.deviceCapturedAt,
    this.phone,
    this.consentTextVersion,
    this.consentGivenAt,
    this.step = '/report/category',
  });

  final String clientSubmissionId;
  final String? categoryId;
  final String? categoryName;
  final String? ccrsNumber;

  /// Compressed photo in the app documents folder.
  final String? photoPath;

  /// Server photo ID after upload.
  final String? photoId;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyM;
  final DateTime? deviceCapturedAt;

  /// Ten-digit local number as typed (normalized on submit).
  final String? phone;
  final String? consentTextVersion;
  final DateTime? consentGivenAt;

  /// Current step route, restored after the OS kills the app.
  final String step;

  bool get hasPhoto => photoPath != null && latitude != null;
  bool get consentGiven => consentGivenAt != null;

  ReportDraft copyWith({
    String? categoryId,
    String? categoryName,
    String? ccrsNumber,
    String? phone,
    String? step,
    String? photoId,
  }) => ReportDraft(
    clientSubmissionId: clientSubmissionId,
    categoryId: categoryId ?? this.categoryId,
    categoryName: categoryName ?? this.categoryName,
    ccrsNumber: ccrsNumber ?? this.ccrsNumber,
    photoPath: photoPath,
    photoId: photoId ?? this.photoId,
    latitude: latitude,
    longitude: longitude,
    gpsAccuracyM: gpsAccuracyM,
    deviceCapturedAt: deviceCapturedAt,
    phone: phone ?? this.phone,
    consentTextVersion: consentTextVersion,
    consentGivenAt: consentGivenAt,
    step: step ?? this.step,
  );

  /// Replaces the photo and its evidence; clears any previous upload.
  ReportDraft withPhoto({
    required String? path,
    required double? latitude,
    required double? longitude,
    required double? accuracy,
    required DateTime? capturedAt,
  }) => ReportDraft(
    clientSubmissionId: clientSubmissionId,
    categoryId: categoryId,
    categoryName: categoryName,
    ccrsNumber: ccrsNumber,
    photoPath: path,
    latitude: latitude,
    longitude: longitude,
    gpsAccuracyM: accuracy,
    deviceCapturedAt: capturedAt,
    phone: phone,
    consentTextVersion: consentTextVersion,
    consentGivenAt: consentGivenAt,
    step: step,
  );

  ReportDraft withConsent(String? version, DateTime? at) => ReportDraft(
    clientSubmissionId: clientSubmissionId,
    categoryId: categoryId,
    categoryName: categoryName,
    ccrsNumber: ccrsNumber,
    photoPath: photoPath,
    photoId: photoId,
    latitude: latitude,
    longitude: longitude,
    gpsAccuracyM: gpsAccuracyM,
    deviceCapturedAt: deviceCapturedAt,
    phone: phone,
    consentTextVersion: version,
    consentGivenAt: at,
    step: step,
  );

  ReportDraft clearUpload() => ReportDraft(
    clientSubmissionId: clientSubmissionId,
    categoryId: categoryId,
    categoryName: categoryName,
    ccrsNumber: ccrsNumber,
    photoPath: photoPath,
    latitude: latitude,
    longitude: longitude,
    gpsAccuracyM: gpsAccuracyM,
    deviceCapturedAt: deviceCapturedAt,
    phone: phone,
    consentTextVersion: consentTextVersion,
    consentGivenAt: consentGivenAt,
    step: step,
  );

  Map<String, dynamic> toJson() => {
    'clientSubmissionId': clientSubmissionId,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'ccrsNumber': ccrsNumber,
    'photoPath': photoPath,
    'photoId': photoId,
    'latitude': latitude,
    'longitude': longitude,
    'gpsAccuracyM': gpsAccuracyM,
    'deviceCapturedAt': deviceCapturedAt?.toUtc().toIso8601String(),
    'phone': phone,
    'consentTextVersion': consentTextVersion,
    'consentGivenAt': consentGivenAt?.toUtc().toIso8601String(),
    'step': step,
  };

  static ReportDraft? fromJson(Map<String, dynamic> j) {
    final id = j['clientSubmissionId'];
    if (id is! String || id.isEmpty) return null;
    double? d(Object? v) => v is num ? v.toDouble() : null;
    DateTime? t(Object? v) => v is String ? DateTime.tryParse(v) : null;
    String? s(Object? v) => v is String ? v : null;
    return ReportDraft(
      clientSubmissionId: id,
      categoryId: s(j['categoryId']),
      categoryName: s(j['categoryName']),
      ccrsNumber: s(j['ccrsNumber']),
      photoPath: s(j['photoPath']),
      photoId: s(j['photoId']),
      latitude: d(j['latitude']),
      longitude: d(j['longitude']),
      gpsAccuracyM: d(j['gpsAccuracyM']),
      deviceCapturedAt: t(j['deviceCapturedAt']),
      phone: s(j['phone']),
      consentTextVersion: s(j['consentTextVersion']),
      consentGivenAt: t(j['consentGivenAt']),
      step: s(j['step']) ?? '/report/category',
    );
  }
}

/// Entry in "Your reports on this phone" (local only, never synced).
class LocalReport {
  const LocalReport({
    required this.ccrsNumber,
    required this.categoryName,
    required this.createdAt,
  });

  final String ccrsNumber;
  final String categoryName;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'ccrsNumber': ccrsNumber,
    'categoryName': categoryName,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static LocalReport? fromJson(Object? j) {
    if (j is! Map) return null;
    final created = DateTime.tryParse('${j['createdAt']}');
    if (created == null) return null;
    return LocalReport(
      ccrsNumber: '${j['ccrsNumber'] ?? ''}',
      categoryName: '${j['categoryName'] ?? ''}',
      createdAt: created,
    );
  }
}

class Category {
  const Category({required this.id, required this.name});

  final String id;
  final String name;
}
