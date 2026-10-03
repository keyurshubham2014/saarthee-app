import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/analytics/event_queue.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/app_error.dart';
import '../../../core/config/app_config.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/validators.dart';
import '../data/report_draft.dart';
import '../data/report_repository.dart';

/// Consent text version recorded with the report (02 §4.8).
const String kConsentTextVersion = 'v1';

/// Report step routes in order (02 §3.1).
class ReportRoutes {
  const ReportRoutes._();

  static const category = '/report/category';
  static const fileWithAmc = '/report/file-with-amc';
  static const number = '/report/number';
  static const photo = '/report/photo';
  static const phone = '/report/phone';
  static const check = '/report/check';
  static const done = '/report/done';
}

/// Single source of truth for the report draft; persisted on every change
/// (02 §5.1). Never cleared by errors; deleted only after the server confirms.
class ReportDraftController extends Notifier<ReportDraft?> {
  DraftStore get _store => ref.read(draftStoreProvider);

  @override
  ReportDraft? build() => ref.watch(draftStoreProvider).load();

  Future<void> _set(ReportDraft d) async {
    state = d;
    await _store.save(d);
  }

  /// Where "Continue your report" and a cold start resume.
  String resumeRoute() => state?.step ?? ReportRoutes.category;

  /// Starts a draft (new `clientSubmissionId`) if none exists. Returns true
  /// when a new draft was created.
  Future<bool> start() async {
    if (state != null) return false;
    await _set(ReportDraft(clientSubmissionId: const Uuid().v4()));
    ref.read(eventQueueProvider).track(AppEvents.reportOpened);
    return true;
  }

  Future<void> setStep(String route) async {
    final d = state;
    if (d == null || d.step == route) return;
    await _set(d.copyWith(step: route));
  }

  Future<void> setCategory(Category c) async {
    await start();
    await _set(state!.copyWith(categoryId: c.id, categoryName: c.name));
  }

  Future<void> setCcrsNumber(String value) async {
    final d = state;
    if (d == null) return;
    await _set(d.copyWith(ccrsNumber: value.trim()));
  }

  /// Stores a captured photo (moved into the draft folder) with its
  /// evidence. Replaces and deletes any previous draft photo.
  Future<void> setPhoto({
    required String sourcePath,
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime capturedAt,
  }) async {
    final d = state;
    if (d == null) return;
    final kept = await _store.keepPhoto(sourcePath, d.clientSubmissionId);
    final previous = d.photoPath;
    await _set(
      d.withPhoto(
        path: kept,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        capturedAt: capturedAt,
      ),
    );
    if (previous != null && previous != kept) {
      await _store.deletePhoto(previous);
    }
  }

  Future<void> setPhotoId(String id) async {
    final d = state;
    if (d == null) return;
    await _set(d.copyWith(photoId: id));
  }

  /// Clears the uploaded photo ID (e.g. `PHOTO_UNUSABLE`), keeping the file.
  Future<void> clearPhotoUpload() async {
    final d = state;
    if (d == null) return;
    await _set(d.clearUpload());
  }

  /// Drops the photo entirely so the citizen retakes it (`PHOTO_UNUSABLE`).
  Future<void> clearPhoto() async {
    final d = state;
    if (d == null) return;
    final path = d.photoPath;
    await _set(
      d.withPhoto(
        path: null,
        latitude: null,
        longitude: null,
        accuracy: null,
        capturedAt: null,
      ),
    );
    await _store.deletePhoto(path);
  }

  Future<void> setPhone(String digits) async {
    final d = state;
    if (d == null) return;
    await _set(d.copyWith(phone: digits));
  }

  Future<void> setConsent(bool given) async {
    final d = state;
    if (d == null) return;
    await _set(
      given
          ? d.withConsent(kConsentTextVersion, DateTime.now())
          : d.withConsent(null, null),
    );
  }

  /// POST /reports with the same `clientSubmissionId` on every retry. On
  /// 201/200: records it locally, deletes draft and photo. Throws `AppError`
  /// and keeps the draft on failure.
  Future<SubmittedReport> submit() async {
    final d = state;
    if (d == null) throw const AppError(code: AppError.unknownCode);
    final settings = ref.read(appSettingsProvider);
    final body = <String, dynamic>{
      'clientSubmissionId': d.clientSubmissionId,
      if (settings.inviteCode != null) 'inviteCode': settings.inviteCode,
      'categoryId': d.categoryId,
      'ccrsNumber': d.ccrsNumber,
      'photoId': d.photoId,
      'latitude': _round6(d.latitude),
      'longitude': _round6(d.longitude),
      if (d.gpsAccuracyM != null) 'gpsAccuracyM': d.gpsAccuracyM,
      'deviceCapturedAt': d.deviceCapturedAt?.toUtc().toIso8601String(),
      'phone': Validators.normalizePhone(d.phone ?? '') == null
          ? d.phone
          : '+91${Validators.normalizePhone(d.phone!)}',
      'consentGivenAt': d.consentGivenAt?.toUtc().toIso8601String(),
      'consentTextVersion': d.consentTextVersion,
      'platform': appPlatformName(),
      'appVersion': AppConfig.appVersion,
    };
    final result = await ref.read(reportRepositoryProvider).submit(body);
    await _store.addMyReport(
      LocalReport(
        ccrsNumber: d.ccrsNumber ?? '',
        categoryName: d.categoryName ?? '',
        createdAt: result.createdAt,
      ),
    );
    ref.invalidate(myReportsProvider);
    await _store.clear();
    await _store.deletePhoto(d.photoPath);
    state = null;
    ref.invalidate(reportUploadProvider);
    return result;
  }

  Future<void> discard() async {
    final path = state?.photoPath;
    await _store.clear();
    await _store.deletePhoto(path);
    state = null;
    ref.invalidate(reportUploadProvider);
  }

  static double? _round6(double? v) =>
      v == null ? null : double.parse(v.toStringAsFixed(6));
}

final reportDraftProvider =
    NotifierProvider<ReportDraftController, ReportDraft?>(
      ReportDraftController.new,
    );

/// Active categories: cached for the session, last list kept for offline.
class CategoriesController extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final store = ref.read(draftStoreProvider);
    try {
      final items = await ref.read(reportRepositoryProvider).categories();
      if (items.isNotEmpty) await store.saveCategories(items);
      return items;
    } on AppError catch (e) {
      final cached = store.lastCategories();
      if (e.isOffline && cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesController, List<Category>>(
      CategoriesController.new,
    );

/// "Your reports on this phone" (local only).
final myReportsProvider = Provider<List<LocalReport>>(
  (ref) => ref.watch(draftStoreProvider).myReports(),
);

enum UploadStatus { idle, uploading, failed, done }

class UploadState {
  const UploadState({
    this.status = UploadStatus.idle,
    this.progress = 0,
    this.error,
  });

  final UploadStatus status;
  final double progress;
  final AppError? error;
}

/// Report photo upload with progress; failure keeps the photo for retry.
class ReportUploadController extends Notifier<UploadState> {
  @override
  UploadState build() {
    final d = ref.read(reportDraftProvider);
    return d?.photoId != null
        ? const UploadState(status: UploadStatus.done, progress: 1)
        : const UploadState();
  }

  Future<void> upload() async {
    final d = ref.read(reportDraftProvider);
    if (d?.photoPath == null || state.status == UploadStatus.uploading) return;
    if (d!.photoId != null) {
      state = const UploadState(status: UploadStatus.done, progress: 1);
      return;
    }
    state = const UploadState(status: UploadStatus.uploading);
    try {
      final id = await ref
          .read(reportRepositoryProvider)
          .uploadPhoto(
            d.photoPath!,
            onProgress: (p) => state = UploadState(
              status: UploadStatus.uploading,
              progress: p,
            ),
          );
      await ref.read(reportDraftProvider.notifier).setPhotoId(id);
      state = const UploadState(status: UploadStatus.done, progress: 1);
    } on AppError catch (e) {
      state = UploadState(status: UploadStatus.failed, error: e);
    }
  }

  void reset() => state = const UploadState();
}

final reportUploadProvider =
    NotifierProvider<ReportUploadController, UploadState>(
      ReportUploadController.new,
    );
