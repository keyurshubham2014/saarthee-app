import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/staff_api.dart';
import '../shared/staff_shared.dart';
import '../shared/staff_widgets.dart';
import '../shell/staff_motion.dart';
import '../shell/staff_session.dart';
import 'election_mode_section.dart';

/// Feature flags shown under "Features" (TASK-10 §5.2 allow-list).
const staffFeatureKeys = ['relay_enabled', 'alerts_feed_drafts_enabled', 'scorecard_public', 'moderation_sensitive_review'];

final staffSettingsProvider = FutureProvider.autoDispose<Map<String, Object?>>((ref) async {
  final j = await ref.watch(staffApiProvider).settings();
  return {for (final i in (j['items'] as List)) '${(i as Map)['key']}': i['value']};
});

/// `GET /staff/settings/election-mode` (TASK-09's endpoint).
final staffElectionModeProvider = FutureProvider.autoDispose<Json>((ref) async {
  final headers = ref.watch(staffAuthHeadersProvider);
  return ref.watch(apiClientProvider).getJson('/staff/settings/election-mode', headers: headers);
});

/// Settings (TASK-10 §5.4): Election mode (through TASK-09's endpoint) and
/// Features switches. Moderators see everything read-only.
class StaffSettingsScreen extends ConsumerWidget {
  const StaffSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final admin = ref.watch(staffRoleProvider) == 'admin';
    return StaffPageScaffold(
      title: l10n.staffSettingsTitle,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          if (!admin)
            NoticeBanner(key: const Key('staff.settings.readOnly'), kind: NoticeKind.info, message: l10n.staffSettingsReadOnly, rounded: true),
          StaffSectionTitle(l10n.staffSettingsElection),
          StaffCard(
            child: StaffAsync<Json>(
              value: ref.watch(staffElectionModeProvider),
              onRetry: () => ref.invalidate(staffElectionModeProvider),
              builder: (m) => ElectionModeSection(initial: m, readOnly: !admin),
            ),
          ),
          StaffSectionTitle(l10n.staffSettingsFeatures),
          StaffCard(
            padding: EdgeInsets.zero,
            child: StaffAsync<Map<String, Object?>>(
              value: ref.watch(staffSettingsProvider),
              onRetry: () => ref.invalidate(staffSettingsProvider),
              builder: (values) => Column(
                children: [
                  for (final key in staffFeatureKeys)
                    SwitchListTile(
                      key: Key('staff.settings.$key'),
                      value: values[key] == true,
                      title: Text(_title(l10n, key)),
                      subtitle: Text(_help(l10n, key)),
                      onChanged: !admin
                          ? null
                          : (v) async {
                              try {
                                await ref.read(staffApiProvider).putSetting(key, v);
                                if (context.mounted) showStaffToast(context, l10n.staffDone);
                              } catch (e) {
                                if (context.mounted) showStaffToast(context, staffErrorText(l10n, e), error: true);
                              }
                              ref.invalidate(staffSettingsProvider);
                            },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _title(AppLocalizations l10n, String key) => switch (key) {
    'relay_enabled' => l10n.staffSettingsRelay,
    'alerts_feed_drafts_enabled' => l10n.staffSettingsDrafts,
    'scorecard_public' => l10n.staffSettingsScorecard,
    _ => l10n.staffSettingsSensitive,
  };

  String _help(AppLocalizations l10n, String key) => switch (key) {
    'relay_enabled' => l10n.staffSettingsRelayHelp,
    'alerts_feed_drafts_enabled' => l10n.staffSettingsDraftsHelp,
    'scorecard_public' => l10n.staffSettingsScorecardHelp,
    _ => l10n.staffSettingsSensitiveHelp,
  };
}
