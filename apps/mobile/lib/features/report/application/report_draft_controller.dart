import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/settings/app_settings.dart';
import '../data/report_draft_model.dart';

export '../data/report_draft_model.dart';

/// shared_preferences key of the v2 draft.
const String kReportDraftKey = 'v2.reportDraft';

/// Directory for draft photo files (overridden in tests).
final reportPhotoDirProvider = FutureProvider<Directory>((ref) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/report_photos');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
});

/// The persisted report draft (TASK-05 §5.2, REQ-F-017). Every change is
/// written to shared_preferences at once, so the draft survives app kill and
/// the camera hand-off. A stored v1 draft (no `schemaVersion`) is discarded
/// together with its photo files.
class ReportDraftController extends Notifier<ReportDraft?> {
  @override
  ReportDraft? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(kReportDraftKey);
    if (raw == null) return null;
    final draft = ReportDraft.decode(raw);
    if (draft == null) {
      for (final p in ReportDraft.legacyPhotoPaths(raw)) {
        _deleteQuietly(p);
      }
      prefs.remove(kReportDraftKey);
    }
    return draft;
  }

  void _save(ReportDraft? next) {
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    if (next == null) {
      prefs.remove(kReportDraftKey);
    } else {
      prefs.setString(kReportDraftKey, next.encode());
    }
  }

  ReportDraft _current() =>
      state ?? ReportDraft(clientSubmissionId: const Uuid().v4());

  /// Step 1: the category; moves to step 2.
  void chooseCategory(String slug) {
    final d = _current();
    final changed = d.categorySlug != slug;
    _save(
      d.copy(
        categorySlug: slug,
        step: ReportStep.photo,
        clearReason: changed,
        dismissedDuplicateIds: changed ? const [] : null,
      ),
    );
  }

  void goTo(ReportStep step) => _save(_current().copy(step: step));

  void addPhoto(DraftPhoto photo) =>
      _save(_current().copy(photos: [..._current().photos, photo]));

  void updatePhoto(String localPath, DraftPhoto Function(DraftPhoto) f) {
    final d = state;
    if (d == null) return;
    _save(
      d.copy(
        photos: [for (final p in d.photos) p.localPath == localPath ? f(p) : p],
      ),
    );
  }

  void removePhoto(String localPath) {
    final d = state;
    if (d == null) return;
    _deleteQuietly(localPath);
    _save(d.copy(photos: [...d.photos.where((p) => p.localPath != localPath)]));
  }

  /// Device fix; also places the pin when the citizen has not moved it.
  void setFix(LatLngFix fix) {
    final d = _current();
    _save(d.copy(fix: fix, pin: d.pinAdjusted ? d.pin : fix));
  }

  void movePin(double lat, double lng) {
    final d = _current();
    _save(
      d.copy(
        pin: LatLngFix(lat: lat, lng: lng, accuracyM: d.fix?.accuracyM),
        pinAdjusted: true,
        clearWard: true,
      ),
    );
  }

  void setWard(DraftWard? ward) => _save(
    ward == null
        ? _current().copy(clearWard: true)
        : _current().copy(ward: ward),
  );

  void confirmWard() {
    final w = state?.ward;
    if (w != null) _save(_current().copy(ward: w.confirmedCopy()));
  }

  void setDescription(String text) => _save(_current().copy(description: text));

  void setReason(String code) => _save(_current().copy(structuredReason: code));

  void dismissDuplicate(String issueId) => _save(
    _current().copy(
      dismissedDuplicateIds: [..._current().dismissedDuplicateIds, issueId],
    ),
  );

  /// Deletes the draft and its photo files (after submit or "Add me too").
  void discard() {
    for (final p in state?.photos ?? const <DraftPhoto>[]) {
      _deleteQuietly(p.localPath);
    }
    _save(null);
  }

  static void _deleteQuietly(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException {
      // Best effort: a missing file is fine.
    }
  }
}

final reportDraftProvider =
    NotifierProvider<ReportDraftController, ReportDraft?>(
      ReportDraftController.new,
    );
