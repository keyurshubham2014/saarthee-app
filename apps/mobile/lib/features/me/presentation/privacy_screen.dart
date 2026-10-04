import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/transitions.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/phone_sign_in.dart';
import '../../auth/data/account_models.dart';
import '../application/me_controller.dart';
import 'delete_account_dialog.dart';

const _defaultGrievanceEmail = 'privacy@saarthee.in';

/// `/me/privacy` (REQ-S-003, REQ-S-004): notice, consent switches (core is
/// fixed), "Download my data", "Delete my account", grievance contact and the
/// independence line.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  final Set<ConsentPurpose> _busy = {};

  Future<void> _toggle(ConsentPurpose p, bool value) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy.add(p));
    try {
      await ref.read(meActionsProvider).setConsent(p, value);
    } catch (e) {
      if (mounted) {
        showSaartheeToast(
          context,
          authErrorText(l10n, e),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(p));
    }
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final nav = Navigator.of(context, rootNavigator: true);
    var open = true;
    showSaartheeSheet<void>(
      context: context,
      builder: (c) => Padding(
        key: const Key('privacy.exportSheet'),
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.accountExportPreparing,
              style: Theme.of(c).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s16),
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.s16),
          ],
        ),
      ),
    ).whenComplete(() => open = false);
    try {
      await ref
          .read(meActionsProvider)
          .exportAndShare(subject: l10n.accountExportShareSubject);
    } catch (e) {
      if (mounted) {
        showSaartheeToast(
          context,
          authErrorText(l10n, e),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (open) nav.pop();
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final deleted = await showDeleteAccountDialog(context);
    if (!deleted || !mounted) return;
    // The toast lives in the root overlay, so it stays up after the go.
    showSaartheeToast(context, l10n.accountDeleted);
    GoRouter.of(context).go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final me = ref.watch(meProvider);
    final email = AppConfig.grievanceEmail.isEmpty
        ? _defaultGrievanceEmail
        : AppConfig.grievanceEmail;

    Widget consent(ConsentPurpose p, String title, Me m, {String? subtitle}) =>
        SwitchListTile(
          key: Key('privacy.consent.${p.wire}'),
          title: Text(title, style: text.bodyLarge),
          subtitle: subtitle == null
              ? null
              : Text(subtitle, style: text.bodySmall),
          value: m.consentGranted(p),
          onChanged: _busy.contains(p) ? null : (v) => _toggle(p, v),
        );

    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.accountPrivacyTitle),
      body: me.when(
        loading: () => const SkeletonList(count: 4),
        error: (e, _) => ErrorState(
          message: authErrorText(l10n, e),
          onRetry: () => ref.invalidate(meProvider),
        ),
        data: (m) => m == null
            ? EmptyState(
                message: l10n.authReasonProfile,
                icon: SaartheeIcons.lock,
              )
            : ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.gutter),
                    child: Text(
                      l10n.accountPrivacySummary,
                      style: text.bodyLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.accountConsentsTitle,
                        style: text.titleLarge,
                      ),
                    ),
                  ),
                  ListRow(
                    key: const Key('privacy.consent.core_service'),
                    leading: Icon(SaartheeIcons.lock, color: c.textSecondary),
                    title: l10n.accountConsentCore,
                    subtitle: l10n.accountConsentCoreFixed,
                    showChevron: false,
                  ),
                  consent(
                    ConsentPurpose.shareWithRepresentatives,
                    l10n.accountConsentShareReps,
                    m,
                  ),
                  consent(
                    ConsentPurpose.shareWithAmcHandoff,
                    l10n.accountConsentAmcHandoff,
                    m,
                  ),
                  consent(
                    ConsentPurpose.notifications,
                    l10n.accountConsentNotifications,
                    m,
                    subtitle: l10n.accountConsentNotificationsHelper,
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SecondaryButton(
                          key: const Key('privacy.download'),
                          label: l10n.accountDownloadData,
                          icon: SaartheeIcons.download,
                          onPressed: _export,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        OutlinedButton.icon(
                          key: const Key('privacy.delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.error,
                            side: BorderSide(
                              color: c.error,
                              width: AppSpacing.outlineWidth,
                            ),
                          ),
                          icon: const Icon(SaartheeIcons.delete),
                          label: Text(l10n.accountDeleteAccount),
                          onPressed: _delete,
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        Text(
                          l10n.accountGrievance(email),
                          style: text.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        const IndependenceNotice(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
