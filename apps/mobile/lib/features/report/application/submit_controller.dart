import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/app_error.dart';
import '../../../core/config/app_config.dart';
import '../data/report_api.dart';
import 'report_draft_controller.dart';
import 'report_providers.dart';

/// Submit state for step 3 (TASK-05 §6 step 18).
class SubmitState {
  const SubmitState({
    this.sending = false,
    this.error,
    this.waitingForNetwork = false,
  });

  final bool sending;
  final AppError? error;

  /// Offline: the draft is kept and sent again on reconnect with the same
  /// `clientSubmissionId`.
  final bool waitingForNetwork;
}

/// Builds the `POST /issues` body from the draft.
Map<String, Object?> issueBody(ReportDraft d, {required bool sensitive}) {
  final pin = d.pin!;
  final first = d.photos.first.capturedAt;
  final description = d.description.trim();
  return {
    'clientSubmissionId': d.clientSubmissionId,
    'categorySlug': d.categorySlug,
    'photoIds': [for (final p in d.photos) p.photoId],
    'latitude': double.parse(pin.lat.toStringAsFixed(6)),
    'longitude': double.parse(pin.lng.toStringAsFixed(6)),
    if (d.fix?.accuracyM != null) 'gpsAccuracyM': d.fix!.accuracyM,
    'pinAdjusted': d.pinAdjusted,
    if (d.pinAdjusted && d.fix != null) ...{
      'fixLatitude': d.fix!.lat,
      'fixLongitude': d.fix!.lng,
    },
    'deviceCapturedAt': first.toUtc().toIso8601String(),
    if (!sensitive && description.isNotEmpty) 'description': description,
    if (sensitive) 'structuredReason': d.structuredReason,
    if (d.ward?.confirm == true && d.ward!.confirmed)
      'confirmedWardId': d.ward!.id,
    'platform': appPlatformName(),
    'appVersion': AppConfig.appVersion,
  };
}

class SubmitController extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  /// Sends the draft; on success clears it and returns the issue. Business
  /// errors keep the draft (AC-8).
  Future<SubmittedIssue?> submit() async {
    final draft = ref.read(reportDraftProvider);
    if (draft == null || state.sending) return null;
    final cats = ref.read(reportCategoriesProvider).value;
    final sensitive =
        cats?.bySlug(draft.categorySlug)?.sensitive ??
        kStructuredReasons.containsKey(draft.categorySlug);
    state = const SubmitState(sending: true);
    try {
      final res = await ref
          .read(reportApiProvider)
          .submit(issueBody(draft, sensitive: sensitive));
      final issue = SubmittedIssue.fromJson(
        res,
        categorySlug: draft.categorySlug ?? 'other',
        lat: draft.pin!.lat,
        lng: draft.pin!.lng,
      );
      ref.read(lastSubmissionProvider.notifier).set(issue);
      ref.read(reportDraftProvider.notifier).discard();
      state = const SubmitState();
      return issue;
    } on AppError catch (e) {
      state = SubmitState(error: e, waitingForNetwork: e.isOffline);
      return null;
    }
  }

  void clearError() => state = const SubmitState();
}

final submitControllerProvider =
    NotifierProvider<SubmitController, SubmitState>(SubmitController.new);
