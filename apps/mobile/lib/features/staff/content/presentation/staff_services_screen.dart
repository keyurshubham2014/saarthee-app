import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../data/staff_content_api.dart';
import 'staff_gate.dart';

final staffServicesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, bool>(
      (ref, brokenOnly) =>
          ref.watch(staffContentApiProvider).services(brokenOnly: brokenOnly),
    );

/// `/staff/services` (TASK-12 §5.4): link status, last checked, verified;
/// "Broken links only"; Edit / Check link now / Deactivate. Moderators read
/// and re-check; only admins edit.
class StaffServicesScreen extends ConsumerStatefulWidget {
  const StaffServicesScreen({super.key});

  @override
  ConsumerState<StaffServicesScreen> createState() =>
      _StaffServicesScreenState();
}

class _StaffServicesScreenState extends ConsumerState<StaffServicesScreen> {
  bool _brokenOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isAdmin = ref.watch(staffRoleProvider) == 'admin';
    final async = ref.watch(staffServicesProvider(_brokenOnly));
    final api = ref.read(staffContentApiProvider);

    String linkStatus(Map<String, dynamic> s) => switch (s['linkOk']) {
      true => l10n.staffContentLinkOk,
      false => l10n.staffContentLinkBroken(
        '${s['linkStatusCode'] ?? s['linkError'] ?? ''}',
      ),
      _ => l10n.staffContentLinkNotChecked,
    };

    String? when(Object? iso) {
      final d = DateTime.tryParse('${iso ?? ''}');
      return d == null ? null : Formatters.date(d, locale);
    }

    return StaffPage(
      title: l10n.staffContentServicesTitle,
      roles: adminOrModerator,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              key: const Key('staff.services.new'),
              onPressed: () => context.push('/staff/services/new'),
              icon: const Icon(SaartheeIcons.add),
              label: Text(l10n.staffContentNewService),
            )
          : null,
      child: Column(
        children: [
          SwitchListTile(
            key: const Key('staff.services.brokenOnly'),
            title: Text(l10n.staffContentBrokenOnly),
            value: _brokenOnly,
            onChanged: (v) => setState(() => _brokenOnly = v),
          ),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (_, _) => ErrorState(
                message: l10n.staffContentLoadError,
                onRetry: () =>
                    ref.invalidate(staffServicesProvider(_brokenOnly)),
              ),
              data: (rows) => ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = rows[i];
                  final id = '${s['id']}';
                  final checked = when(s['lastCheckedAt']);
                  final verified = when(s['verifiedAt']);
                  return ListTile(
                    key: Key('staff.service.${s['slug']}'),
                    title: Text(str(s['nameEn']), style: text.titleMedium),
                    subtitle: Text(
                      [
                        '${s['category']}',
                        linkStatus(s),
                        ?(checked == null
                            ? null
                            : l10n.staffContentLastChecked(checked)),
                        ?(verified == null
                            ? null
                            : l10n.staffContentVerified(verified)),
                        if (s['isActive'] != true) l10n.staffContentInactive,
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(
                        color: s['linkOk'] == false ? c.error : c.textSecondary,
                      ),
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: l10n.staffContentCheckNow,
                          icon: const Icon(SaartheeIcons.refresh),
                          onPressed: () async {
                            await api.checkLink(id);
                            ref.invalidate(staffServicesProvider(_brokenOnly));
                          },
                        ),
                        if (isAdmin) ...[
                          IconButton(
                            tooltip: l10n.staffContentEdit,
                            icon: const Icon(SaartheeIcons.editNote),
                            onPressed: () =>
                                context.push('/staff/services/$id', extra: s),
                          ),
                          if (s['isActive'] == true)
                            IconButton(
                              tooltip: l10n.staffContentDeactivate,
                              icon: const Icon(SaartheeIcons.block),
                              onPressed: () async {
                                await api.deactivateService(id);
                                ref.invalidate(
                                  staffServicesProvider(_brokenOnly),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
