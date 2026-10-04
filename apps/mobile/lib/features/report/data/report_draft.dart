/// Local report draft v2 (TASK-05 §5.2): JSON in shared_preferences, photo
/// files in app documents. v1 drafts (no `schemaVersion`) are discarded.
library;

enum ReportStep { what, photo, details }

enum UploadState { pending, blurring, uploading, uploaded, failed }

class DraftPhoto {
  const DraftPhoto({
    required this.localPath,
    required this.capturedAt,
    this.photoId,
    this.blurApplied = false,
    this.uploadState = UploadState.pending,
    this.progress = 0,
    this.revision = 0,
  });

  factory DraftPhoto.fromJson(Map<String, dynamic> j) => DraftPhoto(
    localPath: j['localPath'] as String,
    capturedAt: DateTime.parse(j['capturedAt'] as String),
    photoId: j['photoId'] as String?,
    blurApplied: j['blurApplied'] == true,
    uploadState: UploadState.values.firstWhere(
      (s) => s.name == j['uploadState'],
      orElse: () => UploadState.pending,
    ),
  );

  final String localPath;
  final DateTime capturedAt;
  final String? photoId;
  final bool blurApplied;
  final UploadState uploadState;

  /// Upload progress 0–1 (memory only).
  final double progress;

  /// Bumped every time the file at [localPath] is rewritten (blur pass,
  /// manual blur), so the thumbnail reloads it instead of a cached or
  /// failed image for the same path (memory only).
  final int revision;

  bool get uploaded => uploadState == UploadState.uploaded && photoId != null;

  DraftPhoto copy({
    String? photoId,
    bool? blurApplied,
    UploadState? uploadState,
    double? progress,
    int? revision,
  }) => DraftPhoto(
    localPath: localPath,
    capturedAt: capturedAt,
    photoId: photoId ?? this.photoId,
    blurApplied: blurApplied ?? this.blurApplied,
    uploadState: uploadState ?? this.uploadState,
    progress: progress ?? this.progress,
    revision: revision ?? this.revision,
  );

  Map<String, Object?> toJson() => {
    'localPath': localPath,
    'capturedAt': capturedAt.toIso8601String(),
    'photoId': photoId,
    'blurApplied': blurApplied,
    // An interrupted upload restarts after a relaunch.
    'uploadState': switch (uploadState) {
      UploadState.uploaded => UploadState.uploaded.name,
      UploadState.failed => UploadState.failed.name,
      _ => UploadState.pending.name,
    },
  };
}

class LatLngFix {
  const LatLngFix({required this.lat, required this.lng, this.accuracyM});

  factory LatLngFix.fromJson(Map<String, dynamic> j) => LatLngFix(
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    accuracyM: (j['accuracyM'] as num?)?.toDouble(),
  );

  final double lat;
  final double lng;
  final double? accuracyM;

  Map<String, Object?> toJson() => {
    'lat': lat,
    'lng': lng,
    if (accuracyM != null) 'accuracyM': accuracyM,
  };
}

class DraftWard {
  const DraftWard({
    required this.id,
    required this.nameEn,
    required this.nameGu,
    required this.zoneEn,
    required this.zoneGu,
    required this.confirm,
    this.confirmed = false,
  });

  factory DraftWard.fromJson(Map<String, dynamic> j) => DraftWard(
    id: j['id'] as String,
    nameEn: j['nameEn'] as String? ?? '',
    nameGu: j['nameGu'] as String? ?? '',
    zoneEn: j['zoneEn'] as String? ?? '',
    zoneGu: j['zoneGu'] as String? ?? '',
    confirm: j['confirm'] == true,
    confirmed: j['confirmed'] == true,
  );

  final String id;
  final String nameEn;
  final String nameGu;
  final String zoneEn;
  final String zoneGu;

  /// Just outside every ward: the citizen must confirm this nearest ward.
  final bool confirm;
  final bool confirmed;

  String name(String lang) => lang == 'gu' ? nameGu : nameEn;
  String zone(String lang) => lang == 'gu' ? zoneGu : zoneEn;

  DraftWard confirmedCopy() => DraftWard(
    id: id,
    nameEn: nameEn,
    nameGu: nameGu,
    zoneEn: zoneEn,
    zoneGu: zoneGu,
    confirm: confirm,
    confirmed: true,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'nameEn': nameEn,
    'nameGu': nameGu,
    'zoneEn': zoneEn,
    'zoneGu': zoneGu,
    'confirm': confirm,
    'confirmed': confirmed,
  };
}
