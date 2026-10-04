import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../application/ward_providers.dart';
import '../data/ward_models.dart';
import '../../rep_claim/data/rep_claim_api.dart';
import '../../rep_claim/presentation/verified_rep_badge.dart';
import 'election_banner.dart';
import 'rep_row.dart';

/// `/representatives/:id` (TASK-09 §5.4, REQ-F-043): names in both scripts,
/// role line, party as plain text, term, office phone only if published,
/// "Message `name`", source and last-checked date, neutrality line.
class RepresentativeScreen extends ConsumerWidget {
  const RepresentativeScreen({super.key, required this.repId});

  final String repId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(repDetailProvider(repId));
    return Scaffold(
      appBar: SaartheeAppBar(
        title: async.value == null
            ? l10n.navMyWard
            : repRoleLabel(l10n, async.value!.summary.role),
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) {
          final err = AppError.from(e);
          void retry() => ref.invalidate(repDetailProvider(repId));
          if (err.statusCode == 404 || err.code == 'NOT_FOUND') {
            return EmptyState(
              key: const Key('rep.notFound'),
              message: l10n.repNotFound,
            );
          }
          return err.isOffline
              ? OfflineState(onRetry: retry)
              : ErrorState(message: l10n.repLoadError, onRetry: retry);
        },
        data: (rep) => _Profile(rep: rep),
      ),
    );
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({required this.rep});

  final RepDetail rep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    final locale = Localizations.localeOf(context).languageCode;
    final s = rep.summary;
    final role = repRoleLabel(l10n, s.role);
    final roleLine = s.role == 'corporator' && s.wardNumber != null
        ? l10n.repRoleLineCorporator(s.wardNumber!, rep.wardName(lang) ?? '')
        : l10n.repRoleLineArea(role, s.area(lang) ?? '');
    final start = rep.termStart;
    final end = rep.termEnd;
    final launch = ref.read(wardLauncherProvider);
    final phone = rep.officePhone;
    final checked = rep.lastVerifiedAt;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.s24),
      children: [
        ElectionBanner(status: rep.election),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Row(
            children: [
              RepAvatar(initials: s.initials, size: 56),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(s.name(lang), style: text.headlineSmall),
                    ),
                    Text(
                      s.otherName(lang),
                      style: text.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                    Text(
                      roleLine,
                      key: const Key('rep.roleLine'),
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // TASK-11: verified badge / ended with term / "Claim this profile".
        VerifiedRepBadge(
          verification: rep.verificationJson == null
              ? RepVerification(status: s.verified ? 'verified' : 'unverified')
              : RepVerification.fromJson(rep.verificationJson),
          repId: s.id,
          name: s.name(lang),
          canClaim: end == null || !end.isBefore(DateTime.now()),
        ),
        if (s.partyText != null)
          ListRow(title: l10n.repParty(s.partyText!), showChevron: false),
        if (start != null)
          ListRow(
            key: const Key('rep.term'),
            title: end == null
                ? l10n.repTermOpen('${start.year}')
                : l10n.repTerm('${start.year}', '${end.year}'),
            showChevron: false,
          ),
        if (phone != null)
          ListRow(
            key: const Key('rep.officePhone'),
            leading: Icon(SaartheeIcons.phone, color: c.textSecondary),
            title: phone,
            subtitle: l10n.repOfficePhone,
            trailing: TextButton(
              onPressed: () => launch(Uri(scheme: 'tel', path: phone)),
              child: Text(l10n.myWardOfficeCall),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                key: const Key('rep.messageButton'),
                label: l10n.repMessageButton(s.name(lang)),
                icon: SaartheeIcons.message,
                onPressed: s.canMessage
                    ? () => context.push('/representatives/${s.id}/message')
                    : null,
              ),
              if (!s.canMessage) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  l10n.repNoEmail,
                  key: const Key('rep.noEmail'),
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (rep.sourceUrl.isNotEmpty)
          ListRow(
            key: const Key('rep.source'),
            leading: Icon(SaartheeIcons.description, color: c.textSecondary),
            title: l10n.repSource(
              rep.sourceDomain,
              checked == null ? '—' : Formatters.date(checked, locale),
            ),
            onTap: () => launch(Uri.parse(rep.sourceUrl)),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Text(l10n.repNeutrality, style: text.bodySmall),
        ),
      ],
    );
  }
}
