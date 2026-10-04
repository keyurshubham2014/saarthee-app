import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/rise_in.dart';
import '../../../core/push/push_registrar.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/data/account_models.dart';
import '../application/me_controller.dart';

/// Home soft prompt before the OS notification permission (TASK-04 §5.4):
/// "Get alerts for Ward 12?" — "Turn on" / "Not now". Never at first launch;
/// a DS §5 card that rises in once and never pulses.
class PushPromptCard extends ConsumerStatefulWidget {
  const PushPromptCard({super.key});

  @override
  ConsumerState<PushPromptCard> createState() => _PushPromptCardState();
}

class _PushPromptCardState extends ConsumerState<PushPromptCard> {
  bool _hidden = false;
  bool _working = false;

  Future<void> _turnOn() async {
    setState(() => _working = true);
    try {
      if (ref.read(sessionProvider).signedIn) {
        await ref
            .read(meActionsProvider)
            .setConsent(ConsentPurpose.notifications, true);
      } else {
        await ref.read(pushRegistrarProvider).enable();
      }
    } catch (_) {
      await ref.read(pushRegistrarProvider).enable();
    }
    if (mounted) setState(() => _hidden = true);
  }

  Future<void> _notNow() async {
    await ref.read(pushRegistrarProvider).dismissPrompt();
    if (mounted) setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    final registrar = ref.watch(pushRegistrarProvider);
    if (_hidden || !registrar.shouldPrompt) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final ward = ref.watch(homeWardProvider);
    return RiseIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.s16,
          AppSpacing.gutter,
          0,
        ),
        child: Container(
          key: const Key('home.pushPrompt'),
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: AppElevation.cardDecoration(c),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(SaartheeIcons.notifications, color: c.primary),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      ward == null
                          ? l10n.accountPushPromptTitleCity
                          : l10n.accountPushPromptTitle(ward.number),
                      style: text.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(l10n.accountPushPromptBody, style: text.bodyMedium),
              const SizedBox(height: AppSpacing.s12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TertiaryButton(
                    key: const Key('home.pushPrompt.notNow'),
                    label: l10n.accountPushNotNow,
                    onPressed: _working ? null : _notNow,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  SecondaryButton(
                    key: const Key('home.pushPrompt.turnOn'),
                    label: l10n.accountPushTurnOn,
                    isLoading: _working,
                    onPressed: _turnOn,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
