import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/session_controller.dart';
import '../../onboarding/presentation/ward_picker_sheet.dart';
import '../application/alert_settings_controller.dart';
import '../data/alert_models.dart';
import 'alert_labels.dart';

/// `/alerts/settings` (REQ-F-039): extra wards (≤ 5), alert types, "Only
/// critical alerts", quiet-hours note; visitors save per device.
/// [highlightType] comes from "Turn off alerts like this".
class AlertSettingsScreen extends ConsumerWidget {
  const AlertSettingsScreen({super.key, this.highlightType});

  final AlertType? highlightType;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    AlertSubscriptions next,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(alertSettingsProvider.notifier).save(next);
    } catch (_) {
      if (context.mounted) {
        showSaartheeToast(
          context,
          l10n.alertsSettingsSaveError,
          kind: ToastKind.error,
        );
      }
    }
  }

  Future<void> _addWard(
    BuildContext context,
    WidgetRef ref,
    AlertSubscriptions s,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (s.extraWardIds.length >= maxExtraWards) {
      showSaartheeToast(
        context,
        l10n.alertsSettingsMaxWards,
        kind: ToastKind.info,
      );
      return;
    }
    final Ward? picked = await showWardPicker(context);
    if (picked == null || !context.mounted) return;
    final home = ref.read(homeWardProvider)?.id;
    if (picked.id == home || s.extraWardIds.contains(picked.id)) return;
    await _save(
      context,
      ref,
      s.copyWith(extraWardIds: [...s.extraWardIds, picked.id]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final text = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    final state = ref.watch(alertSettingsProvider);
    final home = ref.watch(homeWardProvider);
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final wards = ref.watch(wardsListProvider).value?.wards ?? const <Ward>[];
    String wardLabel(String id) =>
        wards.where((w) => w.id == id).firstOrNull?.shortLabel(lang) ?? '';
    Widget heading(String t) => Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sectionTitleTop,
        bottom: AppSpacing.s8,
      ),
      child: Semantics(header: true, child: Text(t, style: text.titleMedium)),
    );
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.alertsSettingsTitle),
      body: state.when(
        loading: () => const SkeletonList(count: 4),
        error: (_, _) => ErrorState(
          message: l10n.alertsSettingsSaveError,
          onRetry: () => ref.invalidate(alertSettingsProvider),
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          children: [
            if (!signedIn) ...[
              const SizedBox(height: AppSpacing.s12),
              NoticeBanner(
                kind: NoticeKind.info,
                message: l10n.alertsSettingsVisitor,
                rounded: true,
              ),
            ],
            heading(l10n.alertsSettingsYourWards),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(SaartheeIcons.location),
              title: Text(
                l10n.alertsSettingsHomeWard(home?.shortLabel(lang) ?? '—'),
              ),
              subtitle: Text(l10n.alertsSettingsChangeInProfile),
            ),
            for (final id in s.extraWardIds)
              ListTile(
                key: ValueKey('extraWard.$id'),
                contentPadding: EdgeInsets.zero,
                title: Text(wardLabel(id)),
                trailing: IconButton(
                  tooltip: l10n.alertsSettingsRemoveWard(wardLabel(id)),
                  icon: const Icon(SaartheeIcons.close),
                  onPressed: () => _save(
                    context,
                    ref,
                    s.copyWith(extraWardIds: [...s.extraWardIds]..remove(id)),
                  ),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('alertsAddWard'),
                onPressed: () => _addWard(context, ref, s),
                icon: const Icon(SaartheeIcons.add),
                label: Text(l10n.alertsSettingsAddWard),
              ),
            ),
            heading(l10n.alertsSettingsTypes),
            for (final t in AlertType.values)
              Container(
                key: ValueKey('alertType.${t.api}'),
                decoration: BoxDecoration(
                  color: t == highlightType ? c.primaryContainer : null,
                  borderRadius: AppRadii.controlRadius,
                ),
                child: SwitchListTile(
                  title: Text(alertTypeLabel(l10n, t)),
                  value: !s.mutedTypes.contains(t),
                  onChanged: (on) => _save(
                    context,
                    ref,
                    s.copyWith(
                      mutedTypes: on
                          ? ({...s.mutedTypes}..remove(t))
                          : {...s.mutedTypes, t},
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              child: Text(
                l10n.alertsSettingsMutedNote,
                style: text.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            SwitchListTile(
              key: const ValueKey('alertsCriticalOnly'),
              title: Text(l10n.alertsSettingsCriticalOnly),
              value: s.criticalOnly,
              onChanged: (v) =>
                  _save(context, ref, s.copyWith(criticalOnly: v)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
              child: Text(
                l10n.alertsSettingsQuietHours,
                style: text.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ),
            if (!signedIn)
              TextButton(
                onPressed: () => context.push('/sign-in?from=/alerts/settings'),
                child: Text(l10n.inboxSignIn),
              ),
          ],
        ),
      ),
    );
  }
}
