import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import 'report_draft_controller.dart';

enum SubmitStatus { idle, sending, failed, done }

class SubmitState {
  const SubmitState({this.status = SubmitStatus.idle, this.error});

  final SubmitStatus status;
  final AppError? error;
}

/// Sends the draft (02 §4.9). The draft is kept on every failure.
class ReportSubmitController extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  Future<bool> send() async {
    if (state.status == SubmitStatus.sending) return false;
    state = const SubmitState(status: SubmitStatus.sending);
    try {
      await ref.read(reportDraftProvider.notifier).submit();
      state = const SubmitState(status: SubmitStatus.done);
      return true;
    } on AppError catch (e) {
      if (e.code == 'PHOTO_UNUSABLE') {
        // Expired or already used: the citizen must retake.
        await ref.read(reportDraftProvider.notifier).clearPhoto();
        ref.read(reportUploadProvider.notifier).reset();
      }
      state = SubmitState(status: SubmitStatus.failed, error: e);
      return false;
    }
  }
}

final reportSubmitProvider =
    NotifierProvider.autoDispose<ReportSubmitController, SubmitState>(
      ReportSubmitController.new,
    );
