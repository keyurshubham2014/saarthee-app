import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/event_queue.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../application/verify_session_controller.dart';
import '../application/verify_token.dart';

/// `/verify` entry (02 §4.11). The token is already in memory; it never
/// appears in this route's location.
class VerifyEntryScreen extends ConsumerWidget {
  const VerifyEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = ref.watch(verifySessionProvider);
    final c = ref.read(verifySessionProvider.notifier);

    void close() {
      c.finish();
      context.go('/');
    }

    // Only full-screen spinner allowed (02 §9.3).
    if (s.load == VerifyLoad.loading) {
      return Scaffold(
        body: Center(
          child: Semantics(
            liveRegion: true,
            label: l10n.verifyEntryLoading,
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (s.load != VerifyLoad.ready || s.summary == null) {
      final e = s.loadError;
      final offline = e?.isOffline ?? false;
      final String message;
      if (e == null) {
        message = l10n.verifySessionEnded;
      } else if (e.code == 'VERIFY_TOKEN_INVALID') {
        message = l10n.verifyLinkInvalid;
      } else if (e.code == 'VERIFY_TOKEN_REVOKED') {
        message = l10n.verifyLinkRevoked;
      } else {
        message = appErrorMessage(l10n, e);
      }
      return StepScaffold(
        title: l10n.homeFollowUpTitle,
        onBack: close,
        showOfflineBanner: offline,
        onRetryOffline: offline ? c.reload : null,
        actions: [
          if (offline || e?.isRateLimited == true)
            PrimaryButton(
              key: const Key('verify.entry.retry'),
              label: l10n.commonRetry,
              onPressed: c.reload,
            ),
          SecondaryButton(
            key: const Key('verify.entry.enterCode'),
            label: l10n.verifyEnterCodeInstead,
            icon: Icons.keyboard_rounded,
            onPressed: () {
              c.finish();
              context.go(VerifyRoutes.enterCode);
            },
          ),
        ],
        children: [InlineFieldError(message: message)],
      );
    }

    final summary = s.summary!;
    return StepScaffold(
      title: l10n.verifyEntryTitle(Formatters.date(summary.reportedAt)),
      onBack: close,
      actions: [
        PrimaryButton(
          key: const Key('verify.entry.continue'),
          label: l10n.commonContinue,
          onPressed: () => context.go(VerifyRoutes.answer),
        ),
      ],
      children: [
        if (summary.previousVerificationCount > 0) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.waitingTint,
              borderRadius: AppRadii.cardRadius,
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: AppColors.ink),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.verifyEntryAnsweredBefore,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(l10n.verifyEntryCategory, style: theme.textTheme.bodySmall),
        Text(summary.categoryName, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.verifyEntryNumber, style: theme.textTheme.bodySmall),
        Text(summary.ccrsNumber, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        if (s.reportPhoto != null)
          EvidencePhoto(
            image: MemoryImage(s.reportPhoto!),
            capturedAt: summary.reportedAt,
          )
        else
          Text(l10n.verifyEntryNoPhoto, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// `/verify/enter-code` fallback (02 §4.12).
class VerifyEnterCodeScreen extends ConsumerStatefulWidget {
  const VerifyEnterCodeScreen({super.key});

  @override
  ConsumerState<VerifyEnterCodeScreen> createState() =>
      _VerifyEnterCodeScreenState();
}

class _VerifyEnterCodeScreenState extends ConsumerState<VerifyEnterCodeScreen> {
  final _controller = TextEditingController();
  bool _invalidInput = false;
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final token = parseVerifyInput(_controller.text);
    if (token == null) {
      setState(() => _invalidInput = true);
      return;
    }
    setState(() {
      _invalidInput = false;
      _submitted = true;
    });
    ref.read(eventQueueProvider).track(AppEvents.deepLinkFailed, {
      'reason': 'manual_entry',
    });
    await ref.read(verifySessionProvider.notifier).openWithToken(token);
    if (!mounted) return;
    if (ref.read(verifySessionProvider).load == VerifyLoad.ready) {
      context.go(VerifyRoutes.entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = ref.watch(verifySessionProvider);
    final loading = s.load == VerifyLoad.loading;
    final e = _submitted ? s.loadError : null;
    final offline = e?.isOffline ?? false;

    String? error;
    if (_invalidInput) {
      error = l10n.verifyEnterCodeError;
    } else if (e != null && !offline) {
      error = switch (e.code) {
        'VERIFY_TOKEN_INVALID' => l10n.verifyLinkInvalid,
        'VERIFY_TOKEN_REVOKED' => l10n.verifyLinkRevoked,
        _ => appErrorMessage(l10n, e),
      };
    }

    return StepScaffold(
      title: l10n.verifyEnterCodeTitle,
      onBack: () => context.go('/'),
      showOfflineBanner: offline,
      onRetryOffline: offline ? _continue : null,
      actions: [
        PrimaryButton(
          key: const Key('verify.enterCode.continue'),
          label: l10n.commonContinue,
          loading: loading,
          onPressed: _continue,
        ),
      ],
      children: [
        Text(l10n.verifyEnterCodeBody, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          key: const Key('verify.enterCode.field'),
          controller: _controller,
          enabled: !loading,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.url,
          minLines: 1,
          maxLines: 3,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(labelText: l10n.verifyEnterCodeLabel),
          onChanged: (_) {
            if (_invalidInput) setState(() => _invalidInput = false);
          },
        ),
        if (error != null) InlineFieldError(message: error),
      ],
    );
  }
}
