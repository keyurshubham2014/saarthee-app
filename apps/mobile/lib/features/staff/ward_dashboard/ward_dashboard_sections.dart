import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/scorecard/scorecard.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/staff_widgets.dart';
import 'ward_dashboard_models.dart';

/// Session key for first-view motion (DS §6): one per ward and metric.
String wardDashKey(String wardId, String metric) => 'ward-dash-$wardId-$metric';

/// Four stat tiles (count up on the first view of the ward, REQ-F-066).
class WardTotals extends StatelessWidget {
  const WardTotals({super.key, required this.d});

  final WardDashboard d;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final w = d.ward.id;
    final tiles = [
      ('open', d.open, l10n.wardDashOpen),
      ('overdue', d.overdueCount, l10n.wardDashOverdue),
      ('fixed30', d.markedFixed30d, l10n.wardDashFixed30),
      ('verified30', d.verified30d, l10n.wardDashVerified30),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 600 ? 4 : 2;
        final width = (box.maxWidth - AppSpacing.s12 * (cols - 1)) / cols;
        return Wrap(
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          children: [
            for (final (k, v, label) in tiles)
              SizedBox(
                width: width,
                child: ScorecardStatTile(
                  key: Key('wardDash.tile.$k'),
                  value: v.toDouble(),
                  label: label,
                  animateKey: wardDashKey(w, k),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "Open issues by category and age": table (cells do not count up) plus a
/// category-total [ScorecardBar] per row that grows on first view.
class CategoryAgeTable extends StatelessWidget {
  const CategoryAgeTable({super.key, required this.d});

  final WardDashboard d;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final max = d.byCategory.fold<int>(1, (m, r) => math.max(m, r.total));
    Widget cell(String s, {bool head = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Text(s, style: head ? text.labelMedium : text.bodyMedium),
    );
    return StaffCard(
      child: Table(
        key: const Key('wardDash.categoryTable'),
        columnWidths: const {0: FlexColumnWidth(2.4)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              cell(l10n.wardDashColCategory, head: true),
              cell(l10n.wardDashCol0to7, head: true),
              cell(l10n.wardDashCol8to30, head: true),
              cell(l10n.wardDashCol31, head: true),
              cell(l10n.wardDashColTotal, head: true),
            ],
          ),
          for (final r in d.byCategory)
            TableRow(
              key: ValueKey('wardDash.cat.${r.slug}'),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cell(categoryLabel(l10n, r.slug)),
                      ScorecardBar(
                        fraction: r.total / max,
                        animateKey: wardDashKey(d.ward.id, 'cat-${r.slug}'),
                        height: 6,
                      ),
                    ],
                  ),
                ),
                cell('${r.d0to7}'),
                cell('${r.d8to30}'),
                cell('${r.d31Plus}'),
                cell('${r.total}'),
              ],
            ),
        ],
      ),
    );
  }
}

/// Overdue issues (50 oldest by SLA); tap opens the issue.
class OverdueList extends StatelessWidget {
  const OverdueList({super.key, required this.d});

  final WardDashboard d;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (d.overdue.isEmpty) {
      return Text(
        l10n.wardDashOverdueEmpty,
        key: const Key('wardDash.overdueEmpty'),
      );
    }
    return StaffCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final o in d.overdue)
            ListRow(
              key: Key('wardDash.overdue.${o.issueId}'),
              title: o.title,
              subtitle:
                  '${categoryLabel(l10n, o.category)} · ${l10n.wardDashOverdueAge(o.ageDays)}',
              trailing: const OverdueTag(),
              onTap: () => context.push('/issues/${o.issueId}'),
            ),
        ],
      ),
    );
  }
}
