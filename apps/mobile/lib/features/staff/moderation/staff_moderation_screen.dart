import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/session_controller.dart';
import '../dashboard/staff_dashboard_screen.dart';
import '../issues/staff_issue_panel.dart';
import '../shared/staff_labels.dart';
import '../shared/staff_shared.dart';
import '../shared/staff_widgets.dart';
import '../shell/staff_motion.dart';
import '../shell/staff_shell.dart';
import 'moderation_models.dart';

/// Moderation queue (TASK-10 §5.4): Sensitive / Flagged / Outside city wards
/// with counts; list left and issue tools right on wide screens. Tabs switch
/// with a `short` cross-fade (no sliding TabBarView).
class StaffModerationScreen extends ConsumerStatefulWidget {
  const StaffModerationScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<StaffModerationScreen> createState() => _StaffModerationScreenState();
}

class _StaffModerationScreenState extends ConsumerState<StaffModerationScreen> {
  late String _tab = staffQueues.contains(widget.initialTab) ? widget.initialTab! : staffQueues.first;
  String? _selected;

  String _tabLabel(AppLocalizations l10n, String q, StaffSummary? s) => switch (q) {
    'sensitive' => l10n.moderationTabSensitive(s?.sensitive ?? 0),
    'flagged' => l10n.moderationTabFlagged(s?.flagged ?? 0),
    _ => l10n.moderationTabOutside(s?.outside ?? 0),
  };

  void _handled() {
    setState(() => _selected = null);
    ref.invalidate(staffSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(staffSummaryProvider).value;
    final wide = MediaQuery.sizeOf(context).width >= staffWideBreakpoint + 320;
    final list = _QueueList(
      key: ValueKey(_tab),
      queue: _tab,
      selected: _selected,
      onOpen: (id) => wide ? setState(() => _selected = id) : context.push('/staff/issues/$id'),
    );
    return StaffPageScaffold(
      title: l10n.moderationTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s12, AppSpacing.gutter, AppSpacing.s8),
            child: Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                for (final q in staffQueues)
                  ChoiceChip(
                    key: Key('moderation.tab.$q'),
                    label: Text(_tabLabel(l10n, q, summary)),
                    selected: _tab == q,
                    onSelected: (_) => setState(() {
                      _tab = q;
                      _selected = null;
                    }),
                  ),
              ],
            ),
          ),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 2, child: _fade(context, list)),
                      const VerticalDivider(width: AppSpacing.borderWidth),
                      Expanded(
                        flex: 3,
                        child: _fade(
                          context,
                          _selected == null
                              ? Center(key: const Key('moderation.pane.empty'), child: Text(l10n.moderationSelectIssue))
                              : StaffIssuePanel(key: ValueKey(_selected), issueId: _selected!, onHandled: _handled),
                        ),
                      ),
                    ],
                  )
                : _fade(context, list),
          ),
        ],
      ),
    );
  }

  Widget _fade(BuildContext context, Widget child) => AnimatedSwitcher(
    duration: staffFade(context),
    transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
    child: child,
  );
}

class _QueueList extends ConsumerWidget {
  const _QueueList({super.key, required this.queue, required this.selected, required this.onOpen});

  final String queue;
  final String? selected;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final c = SaartheeColors.of(context);
    final token = ref.watch(sessionProvider.select((s) => s.token));
    final headers = token == null ? null : {'Authorization': 'Bearer $token'};
    return StaffAsync<QueuePage>(
      value: ref.watch(staffQueueProvider(queue)),
      onRetry: () => ref.invalidate(staffQueueProvider(queue)),
      builder: (page) => page.items.isEmpty
          ? EmptyState(key: const Key('moderation.empty'), message: l10n.moderationEmpty)
          : RefreshIndicator(
              onRefresh: () => ref.refresh(staffQueueProvider(queue).future),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                itemCount: page.items.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
                itemBuilder: (_, i) {
                  final item = page.items[i];
                  final ward = item.ward == null ? l10n.moderationNoWard : item.ward!.name(lang);
                  return Material(
                    color: item.id == selected ? c.primaryContainer : c.surface,
                    child: ListRow(
                      key: Key('moderation.row.${item.id}'),
                      leading: item.thumbUrl == null
                          ? CategoryBadge(slug: item.categorySlug)
                          : SizedBox(
                              width: 56,
                              height: 56,
                              child: PhotoThumb(
                                semanticLabel: item.title,
                                image: NetworkImage(Uri.parse(AppConfig.apiBaseUrl).resolve(item.thumbUrl!).toString(), headers: headers),
                              ),
                            ),
                      title: item.title,
                      subtitle: [
                        l10n.moderationRowMeta(ward, Formatters.shortDate(item.createdAt)),
                        for (final f in item.openFlags) l10n.moderationFlagCount(flagReasonLabel(l10n, f.reason), f.count),
                      ].join('\n'),
                      onTap: () => onOpen(item.id),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
