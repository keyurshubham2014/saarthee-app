import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/event_queue.dart';
import '../../../core/api/app_error.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/validators.dart';
import '../data/invite_repository.dart';

enum InviteStatus { idle, invalidFormat, checking, success, failed }

class InviteState {
  const InviteState({
    this.status = InviteStatus.idle,
    this.error,
    this.groupLabel,
  });

  final InviteStatus status;
  final AppError? error;
  final String? groupLabel;
}

class InviteController extends Notifier<InviteState> {
  @override
  InviteState build() => const InviteState();

  /// Validates the code; on success stores it and completes onboarding.
  Future<void> submit(String raw) async {
    if (state.status == InviteStatus.checking) return;
    final code = raw.trim().toUpperCase();
    if (!Validators.inviteCode(code)) {
      state = const InviteState(status: InviteStatus.invalidFormat);
      return;
    }
    state = const InviteState(status: InviteStatus.checking);
    try {
      final label = await ref.read(inviteRepositoryProvider).validate(code);
      final settings = ref.read(appSettingsProvider.notifier);
      await settings.setInviteCode(code, label);
      await settings.completeOnboarding();
      ref.read(eventQueueProvider).track(AppEvents.inviteCodeEntered, {
        'valid': true,
      });
      state = InviteState(status: InviteStatus.success, groupLabel: label);
    } on AppError catch (e) {
      if (e.code == 'INVITE_CODE_INVALID') {
        ref.read(eventQueueProvider).track(AppEvents.inviteCodeEntered, {
          'valid': false,
        });
      }
      state = InviteState(status: InviteStatus.failed, error: e);
    }
  }

  /// "I don't have a code": Home with no code stored.
  Future<void> skip() async {
    await ref.read(appSettingsProvider.notifier).clearInviteCode();
    await ref.read(appSettingsProvider.notifier).completeOnboarding();
  }

  void reset() => state = const InviteState();
}

final inviteControllerProvider =
    NotifierProvider.autoDispose<InviteController, InviteState>(
      InviteController.new,
    );
