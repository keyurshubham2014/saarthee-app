import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/alerts/alert_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../inbox/application/inbox_controller.dart';
import '../../inbox/presentation/inbox_bell.dart';
import '../application/alerts_providers.dart';
import '../data/alert_models.dart';
import 'alert_labels.dart';

/// Alerts tab `/alerts` (REQ-F-038): Active / Past for my wards; Critical
/// first as a solid banner card; loading, empty, error and offline states.
class AlertsTabScreen extends ConsumerStatefulWidget {
  const AlertsTabScreen({super.key});

  @override
  ConsumerState<AlertsTabScreen> createState() => _AlertsTabScreenState();
}

class _AlertsTabScreenState extends ConsumerState<AlertsTabScreen> {
  bool _active = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wards = ref.watch(myAlertWardIdsProvider);
    final list = ref.watch(alertsListProvider(_active));
    return Scaffold(
      appBar: SaartheeAppBar(
        title: l10n.alertsTitle,
        showBack: false,
        actions: [
          IconButton(
            key: const ValueKey('alertsSettingsAction'),
            tooltip: l10n.alertsSettingsAction,
            icon: const Icon(SaartheeIcons.settings),
            onPressed: () => context.push('/alerts/settings'),
          ),
        ],
        bell: const InboxBell(),
      ),
      body: ContentWidth(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.s12),
            SegmentedButton<bool>(
              key: const ValueKey('alertsSegment'),
              segments: [
                ButtonSegment(value: true, label: Text(l10n.alertsTabActive)),
                ButtonSegment(value: false, label: Text(l10n.alertsTabPast)),
              ],
              selected: {_active},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _active = s.first),
            ),
            const SizedBox(height: AppSpacing.s12),
            Expanded(
              child: wards.isEmpty
                  ? EmptyState(
                      message: l10n.alertsNoWard,
                      icon: SaartheeIcons.location,
                    )
                  : list.when(
                      loading: () => const SkeletonList(count: 3),
                      error: (_, _) => ErrorState(
                        message: l10n.alertsLoadError,
                        onRetry: () =>
                            ref.invalidate(alertsListProvider(_active)),
                      ),
                      data: (data) => _AlertsList(data: data, active: _active),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsList extends ConsumerWidget {
  const _AlertsList({required this.data, required this.active});

  final AlertsList data;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    if (data.items.isEmpty) {
      return EmptyState(
        message: active ? l10n.alertsEmptyActive : l10n.alertsEmptyPast,
        icon: SaartheeIcons.navAlerts,
        actionLabel: active ? l10n.alertsSettingsAction : null,
        onAction: active ? () => context.push('/alerts/settings') : null,
      );
    }
    return RefreshIndicator(
      onRefresh: () {
        // Keep the bell badge in step with the list (W-FIX-ALR).
        unawaited(ref.read(inboxProvider.notifier).refreshIfIdle());
        return ref.refresh(alertsListProvider(active).future);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.s24),
        children: [
          if (data.fromCache) ...[
            NoticeBanner(
              kind: NoticeKind.offline,
              message: l10n.alertsOfflineCached,
              rounded: true,
            ),
            const SizedBox(height: AppSpacing.cardGap),
          ],
          for (final a in data.items) ...[
            _AlertTile(alert: a, lang: lang),
            const SizedBox(height: AppSpacing.cardGap),
          ],
          const IndependenceFooter(),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.lang});

  final Alert alert;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: alertSemanticsLabel(l10n, lang, alert),
      button: true,
      excludeSemantics: true,
      child: AlertCard(
        key: ValueKey('alertTile.${alert.id}'),
        severity: alert.severity,
        title: alert.title(lang),
        area: alertAreaLabel(l10n, lang, alert),
        validity: alertValidityLabel(l10n, lang, alert),
        source: alert.sourceName,
        onTap: () => context.push('/alerts/${alert.id}'),
      ),
    );
  }
}
