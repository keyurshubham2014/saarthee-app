import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/error_messages.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/invite_controller.dart';

/// `/invite` (02 §4.2).
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _controller = TextEditingController();
  bool _attempted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _attempted = true);
    await ref.read(inviteControllerProvider.notifier).submit(_controller.text);
  }

  Future<void> _skip() async {
    await ref.read(inviteControllerProvider.notifier).skip();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(inviteControllerProvider);

    ref.listen(inviteControllerProvider, (prev, next) {
      if (next.status == InviteStatus.success) {
        final router = GoRouter.of(context);
        Future<void>.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) router.go('/');
        });
      }
    });

    final error = state.error;
    final offline = error?.isOffline ?? false;
    String? inlineError;
    if (state.status == InviteStatus.invalidFormat) {
      inlineError = l10n.inviteFieldInvalidFormat;
    } else if (error != null && !offline) {
      inlineError = appErrorMessage(l10n, error);
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                tooltip: l10n.commonBack,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: PinnedBottomLayout(
        top: offline ? OfflineBanner(onRetry: _submit) : null,
        bottom: [
          PrimaryButton(
            key: const Key('invite.continue'),
            label: l10n.commonContinue,
            loading: state.status == InviteStatus.checking,
            onPressed: state.status == InviteStatus.success ? null : _submit,
          ),
          SecondaryButton(
            key: const Key('invite.skip'),
            label: l10n.inviteNoCode,
            onPressed: state.status == InviteStatus.checking ? null : _skip,
          ),
        ],
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.inviteTitle,
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.inviteBody, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            key: const Key('invite.codeField'),
            controller: _controller,
            enabled: state.status != InviteStatus.checking,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 20,
            style: theme.textTheme.bodyLarge?.copyWith(letterSpacing: 2),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              const _UpperCaseFormatter(),
            ],
            decoration: InputDecoration(
              labelText: l10n.inviteFieldLabel,
              helperText: l10n.inviteFieldHint,
              counterText: '',
            ),
            onChanged: (_) {
              if (_attempted && state.status != InviteStatus.idle) {
                ref.read(inviteControllerProvider.notifier).reset();
              }
            },
            onSubmitted: (_) => _submit(),
          ),
          if (inlineError != null) InlineFieldError(message: inlineError),
          if (state.status == InviteStatus.success &&
              state.groupLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.fixedTint,
                  borderRadius: AppRadii.cardRadius,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.fixed,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        l10n.inviteSuccess(state.groupLabel!),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
