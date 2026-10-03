import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_l10n.dart';
import '../../application/admin_complaints.dart';
import '../../data/models/rate_row.dart';
import '../admin_format.dart';
import '../widgets/admin_tokens.dart';
import '../widgets/admin_widgets.dart';

/// Rows with fewer verified answers than this get the small-sample note
/// (02 §4.21, assumed threshold).
const int smallSampleThreshold = 10;

/// `/admin/rates` (02 §4.21).
class AdminRatesScreen extends ConsumerWidget {
  const AdminRatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final rates = ref.watch(ratesProvider);

    Future<void> refresh() => ref.refresh(ratesProvider.future);

    final Widget body;
    if (rates.hasValue) {
      final snapshot = rates.requireValue;
      final trusted = snapshot.trusted;
      body = ListView(
        key: const Key('adminRatesList'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: adminScreenPadding,
        children: <Widget>[
          if (rates.hasError && !rates.isLoading) ...<Widget>[
            AdminMessageBanner(
              message: l10n.adminRatesLoadFailed,
              onRetry: () => ref.invalidate(ratesProvider),
            ),
            const SizedBox(height: 12),
          ],
          if (snapshot.rows.isEmpty)
            AdminEmptyState(
              icon: Icons.insights_rounded,
              message: l10n.adminRatesEmpty,
            ),
          if (trusted != null) ...<Widget>[
            _RateCard(row: trusted, highlighted: true, locale: locale),
            const SizedBox(height: 8),
          ],
          if (snapshot.rows.isNotEmpty) ...<Widget>[
            Text(l10n.adminRatesNote, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
          for (final row in snapshot.sources) ...<Widget>[
            _RateCard(row: row, highlighted: false, locale: locale),
            const SizedBox(height: 12),
          ],
          Text(
            l10n.adminRatesComputedAt(
              formatIstDateTime(snapshot.computedAt, locale),
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    } else if (rates.hasError) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          AdminErrorView(
            title: l10n.adminRatesLoadFailed,
            error: asAdminError(rates.error!),
            onRetry: () => ref.invalidate(ratesProvider),
          ),
        ],
      );
    } else {
      body = const AdminSkeletonList(count: 4, height: 160);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminRatesTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: AdminContentWidth(child: body),
        ),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.row,
    required this.highlighted,
    required this.locale,
  });

  final RateRow row;
  final bool highlighted;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    final tokens = AdminTokens.of(context);
    final h1 = formatRatePercent(row.h1Rate, locale) ?? l10n.adminRatesNone;
    final h2 = formatRatePercent(row.h2Rate, locale) ?? l10n.adminRatesNone;
    Widget metric(String label, String value, String key) => Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, key: Key(key), style: theme.textTheme.titleLarge),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.inkMuted),
          ),
        ],
      ),
    );
    return Card(
      key: Key('adminRatesRow-${row.group}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: highlighted
          ? tokens.indigoTint
          : theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              highlighted
                  ? l10n.adminRatesTrustedTitle
                  : sourceLabel(l10n, row.group),
              style: theme.textTheme.titleMedium,
            ),
            if (highlighted)
              Text(
                sourceLabel(l10n, row.group),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: <Widget>[
                metric(
                  l10n.adminRatesComplaints,
                  '${row.complaints}',
                  'adminRates-${row.group}-complaints',
                ),
                metric(
                  l10n.adminRatesReminded,
                  '${row.reminded}',
                  'adminRates-${row.group}-reminded',
                ),
                metric(
                  l10n.adminRatesVerified,
                  '${row.verified}',
                  'adminRates-${row.group}-verified',
                ),
                metric(l10n.adminRatesH1, h1, 'adminRates-${row.group}-h1'),
                metric(l10n.adminRatesH2, h2, 'adminRates-${row.group}-h2'),
              ],
            ),
            if (row.verified < smallSampleThreshold) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(Icons.info_outline_rounded, color: tokens.inkMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.adminRatesSmallSample,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
