import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/scorecard/scorecard.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/staff_widgets.dart';
import 'ward_dashboard_models.dart';
import 'ward_dashboard_sections.dart';

/// "Resolution trend": 12 weekly columns (marked fixed) that grow on the
/// first view of the ward (REQ-F-066), with a "Show as table" alternative
/// that reads every number (TalkBack). Toggling back does not replay.
class WardTrend extends StatefulWidget {
  const WardTrend({super.key, required this.d});

  final WardDashboard d;

  @override
  State<WardTrend> createState() => _WardTrendState();
}

class _WardTrendState extends State<WardTrend> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final weeks = widget.d.trend;
    final max = weeks.fold<int>(1, (m, w) => math.max(m, w.markedFixed));
    return StaffCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.wardDashTrendLegend, style: text.bodySmall),
              ),
              TextButton(
                key: const Key('wardDash.trendToggle'),
                onPressed: () => setState(() => _table = !_table),
                child: Text(
                  _table ? l10n.wardDashShowChart : l10n.wardDashShowTable,
                ),
              ),
            ],
          ),
          if (_table)
            Table(
              key: const Key('wardDash.trendTable'),
              children: [
                for (final row in [
                  [
                    l10n.wardDashWeek,
                    l10n.wardDashReported,
                    l10n.wardDashMarkedFixed,
                    l10n.wardDashVerified,
                  ],
                  for (final w in weeks)
                    [
                      w.weekStart,
                      '${w.reported}',
                      '${w.markedFixed}',
                      '${w.verified}',
                    ],
                ])
                  TableRow(
                    children: [
                      for (final c in row)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s4,
                          ),
                          child: Text(c, style: text.bodySmall),
                        ),
                    ],
                  ),
              ],
            )
          else
            Semantics(
              label: l10n.wardDashTrend,
              child: SizedBox(
                key: const Key('wardDash.trendChart'),
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final (i, w) in weeks.indexed)
                      ScorecardBar(
                        key: Key('wardDash.trendBar.$i'),
                        vertical: true,
                        height: 12,
                        fraction: w.markedFixed / max,
                        animateKey: wardDashKey(widget.d.ward.id, 'trend-$i'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hotspots as an accessible list (cells of open issues, largest first).
/// The map layer is Deferred until TASK-07's map widget lands (see §5.6).
class HotspotList extends StatelessWidget {
  const HotspotList({super.key, required this.d});

  final WardDashboard d;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (d.hotspots.isEmpty) return Text(l10n.wardDashHotspotsEmpty);
    return StaffCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final h in d.hotspots)
            // The payload has no locality name and `/map` takes no centre
            // parameter, so the row reads as a count, never raw coordinates.
            ListRow(title: l10n.polishHotspotRow(h.count), showChevron: false),
        ],
      ),
    );
  }
}
