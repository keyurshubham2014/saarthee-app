import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/rep_shared.dart';
import '../shared/staff_widgets.dart';
import 'ward_dashboard_models.dart';
import 'ward_dashboard_providers.dart';
import 'ward_issue_actions.dart';

/// `/staff/ward/issues` (TASK-11 §5.4): the selected scope ward's issues with
/// All / Overdue filter; each row opens the action sheet built from the
/// server's `allowedActions`.
class WardIssuesScreen extends ConsumerStatefulWidget {
  const WardIssuesScreen({super.key});

  @override
  ConsumerState<WardIssuesScreen> createState() => _State();
}

class _State extends ConsumerState<WardIssuesScreen> {
  bool _overdue = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final scope = ref.watch(wardScopeProvider);
    return StaffAsync<List<ScopeWard>>(
      value: scope,
      onRetry: () => ref.invalidate(wardScopeProvider),
      builder: (wards) {
        if (wards.isEmpty) return EmptyState(message: l10n.wardDashNoScope);
        final picked = ref.watch(selectedWardProvider);
        final ward = wards.firstWhere(
          (w) => w.id == picked,
          orElse: () => wards.first,
        );
        final args = (wardId: ward.id, overdue: _overdue);
        final page = ref.watch(wardIssuesProvider(args));
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            Text(
              l10n.wardDashWard(ward.number, ward.name(lang)),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              children: [
                AppFilterChip(
                  key: const Key('wardIssues.all'),
                  label: l10n.wardDashFilterAll,
                  selected: !_overdue,
                  onSelected: (_) => setState(() => _overdue = false),
                ),
                AppFilterChip(
                  key: const Key('wardIssues.overdue'),
                  label: l10n.wardDashFilterOverdue,
                  selected: _overdue,
                  onSelected: (_) => setState(() => _overdue = true),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            StaffAsync<Json>(
              value: page,
              onRetry: () => ref.invalidate(wardIssuesProvider(args)),
              builder: (j) {
                final items = (j['items'] as List? ?? const []).cast<Json>();
                final election =
                    (j['electionMode'] as Json?)?['active'] == true;
                if (items.isEmpty) {
                  return EmptyState(message: l10n.wardDashIssuesEmpty);
                }
                return StaffCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final i in items)
                        ListRow(
                          key: Key('wardIssues.row.${i['id']}'),
                          title: jsonText(i, 'title'),
                          subtitle: categoryLabel(
                            l10n,
                            '${(i['category'] as Json)['slug']}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (i['overdue'] == true) const OverdueTag(),
                              const SizedBox(width: AppSpacing.s4),
                              StatusChip(
                                status: repIssueStatus('${i['status']}'),
                              ),
                            ],
                          ),
                          onTap: () async {
                            final changed = await showWardIssueActions(
                              context,
                              ref,
                              issueId: '${i['id']}',
                              status: '${i['status']}',
                              allowed: [
                                for (final a
                                    in (i['allowedActions'] as List? ??
                                        const []))
                                  '$a',
                              ],
                              electionActive: election,
                            );
                            if (changed) {
                              ref.invalidate(wardIssuesProvider(args));
                            }
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
