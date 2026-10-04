import 'dart:convert';

import 'report_draft.dart';

export 'report_draft.dart';

/// The whole draft (TASK-05 §5.2), `schemaVersion = 2`.
class ReportDraft {
  const ReportDraft({
    required this.clientSubmissionId,
    this.categorySlug,
    this.photos = const [],
    this.fix,
    this.pin,
    this.pinAdjusted = false,
    this.ward,
    this.description = '',
    this.structuredReason,
    this.dismissedDuplicateIds = const [],
    this.step = ReportStep.what,
  });

  static const int schemaVersion = 2;

  final String clientSubmissionId;
  final String? categorySlug;
  final List<DraftPhoto> photos;
  final LatLngFix? fix;
  final LatLngFix? pin;
  final bool pinAdjusted;
  final DraftWard? ward;
  final String description;
  final String? structuredReason;
  final List<String> dismissedDuplicateIds;
  final ReportStep step;

  bool get allUploaded => photos.isNotEmpty && photos.every((p) => p.uploaded);
  bool get wardReady => ward != null && (!ward!.confirm || ward!.confirmed);

  ReportDraft copy({
    String? categorySlug,
    List<DraftPhoto>? photos,
    LatLngFix? fix,
    LatLngFix? pin,
    bool? pinAdjusted,
    DraftWard? ward,
    bool clearWard = false,
    String? description,
    String? structuredReason,
    bool clearReason = false,
    List<String>? dismissedDuplicateIds,
    ReportStep? step,
  }) => ReportDraft(
    clientSubmissionId: clientSubmissionId,
    categorySlug: categorySlug ?? this.categorySlug,
    photos: photos ?? this.photos,
    fix: fix ?? this.fix,
    pin: pin ?? this.pin,
    pinAdjusted: pinAdjusted ?? this.pinAdjusted,
    ward: clearWard ? null : (ward ?? this.ward),
    description: description ?? this.description,
    structuredReason: clearReason
        ? null
        : (structuredReason ?? this.structuredReason),
    dismissedDuplicateIds: dismissedDuplicateIds ?? this.dismissedDuplicateIds,
    step: step ?? this.step,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'clientSubmissionId': clientSubmissionId,
    'categorySlug': categorySlug,
    'photos': [for (final p in photos) p.toJson()],
    'fix': fix?.toJson(),
    'pin': pin == null ? null : {...pin!.toJson(), 'adjusted': pinAdjusted},
    'ward': ward?.toJson(),
    'description': description,
    'structuredReason': structuredReason,
    'dismissedDuplicateIds': dismissedDuplicateIds,
    'step': step.name,
  };

  String encode() => jsonEncode(toJson());

  /// Parses a stored draft; returns null for v1 (no `schemaVersion`), other
  /// versions or corrupt JSON.
  static ReportDraft? decode(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['schemaVersion'] != schemaVersion) return null;
      final pin = j['pin'] as Map<String, dynamic>?;
      return ReportDraft(
        clientSubmissionId: j['clientSubmissionId'] as String,
        categorySlug: j['categorySlug'] as String?,
        photos: [
          for (final p in (j['photos'] as List? ?? const []))
            DraftPhoto.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
        fix: j['fix'] == null
            ? null
            : LatLngFix.fromJson(j['fix'] as Map<String, dynamic>),
        pin: pin == null ? null : LatLngFix.fromJson(pin),
        pinAdjusted: pin?['adjusted'] == true,
        ward: j['ward'] == null
            ? null
            : DraftWard.fromJson(j['ward'] as Map<String, dynamic>),
        description: j['description'] as String? ?? '',
        structuredReason: j['structuredReason'] as String?,
        dismissedDuplicateIds: [
          for (final d in (j['dismissedDuplicateIds'] as List? ?? const []))
            d as String,
        ],
        step: ReportStep.values.firstWhere(
          (s) => s.name == j['step'],
          orElse: () => ReportStep.what,
        ),
      );
    } on Object {
      return null;
    }
  }

  /// Photo paths of a v1 draft JSON (to delete its files on discard).
  static List<String> legacyPhotoPaths(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return const [];
      return [
        for (final k in ['photoPath', 'localPhotoPath'])
          if (j[k] is String) j[k] as String,
      ];
    } on Object {
      return const [];
    }
  }
}
