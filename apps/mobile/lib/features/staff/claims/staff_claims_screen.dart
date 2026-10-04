import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/rep_shared.dart';
import '../shared/staff_widgets.dart';
import '../ward_dashboard/rep_console_api.dart';
import '../ward_dashboard/ward_dashboard_models.dart';

final staffClaimsProvider = FutureProvider.autoDispose.family<Json, String>(
  (ref, status) => ref.watch(repConsoleApiProvider).claims(status),
);

/// Phone-match chip: Yes = success tint + check; No = neutral + cancel.
class PhoneMatchChip extends StatelessWidget {
  const PhoneMatchChip({super.key, required this.match});

  final bool match;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = IssueStatusStyle.of(
      match ? IssueStatus.verified : IssueStatus.reported,
    );
    return ToneChip(
      key: Key('phoneMatch.$match'),
      tone: ToneStyle(
        solid: base.solid,
        tint: base.tint,
        icon: match ? SaartheeIcons.check : SaartheeIcons.cancel,
        l10nKey: base.l10nKey,
      ),
      label: match ? l10n.repClaimPhoneMatchYes : l10n.repClaimPhoneMatchNo,
    );
  }
}

/// `/staff/claims` (admin; moderators read): filter Pending / Approved /
/// Not approved; rows show representative, claimant, ward, phone match,
/// evidence count and submitted date.
class StaffClaimsScreen extends ConsumerStatefulWidget {
  const StaffClaimsScreen({super.key});

  @override
  ConsumerState<StaffClaimsScreen> createState() => _State();
}

class _State extends ConsumerState<StaffClaimsScreen> {
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final locale = Localizations.localeOf(context).languageCode;
    final filters = {
      'pending': l10n.repClaimFilterPending,
      'approved': l10n.repClaimFilterApproved,
      'rejected': l10n.repClaimFilterRejected,
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        Text(
          l10n.repClaimsTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          children: [
            for (final f in filters.entries)
              AppFilterChip(
                key: Key('claims.filter.${f.key}'),
                label: f.value,
                selected: _status == f.key,
                onSelected: (_) => setState(() => _status = f.key),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        StaffAsync<Json>(
          value: ref.watch(staffClaimsProvider(_status)),
          onRetry: () => ref.invalidate(staffClaimsProvider(_status)),
          builder: (j) {
            final items = (j['items'] as List? ?? const []).cast<Json>();
            if (items.isEmpty) {
              return EmptyState(
                key: const Key('claims.empty'),
                message: l10n.repClaimsEmpty,
              );
            }
            return StaffCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final cl in items)
                    ListRow(
                      key: Key('claims.row.${cl['claimId']}'),
                      title:
                          '${(cl['representative'] as Json)[lang == 'gu' ? 'nameGu' : 'nameEn']}',
                      subtitle: [
                        l10n.repClaimClaimant(
                          '${(cl['claimant'] as Json)['displayName'] ?? '—'}',
                        ),
                        l10n.repClaimEvidenceCount(
                          (cl['evidenceCount'] as num).toInt(),
                        ),
                        l10n.repClaimSubmitted(
                          Formatters.date(
                            DateTime.parse('${cl['createdAt']}'),
                            locale,
                          ),
                        ),
                      ].join(' · '),
                      trailing: Wrap(
                        spacing: AppSpacing.s4,
                        children: [
                          PhoneMatchChip(match: cl['phoneMatch'] == true),
                          ClaimStatusChip(status: '${cl['status']}'),
                        ],
                      ),
                      onTap: () async {
                        await context.push('/staff/claims/${cl['claimId']}');
                        ref.invalidate(staffClaimsProvider(_status));
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
