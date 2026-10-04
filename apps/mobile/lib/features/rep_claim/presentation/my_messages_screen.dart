import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';

/// One row of `GET /me/messages` (TASK-11 P2).
class MyRepMessage {
  const MyRepMessage(this.j);

  final Map<String, dynamic> j;

  String get id => '${j['id']}';
  String get subject => '${j['subject'] ?? ''}';
  String get status => '${j['status']}';
  String? get reply => j['reply'] as String?;
  bool get byEmail => j['replyChannel'] == 'email';
  DateTime? get repliedAt => DateTime.tryParse('${j['repliedAt']}');
  String repName(String lang) {
    final r = j['representative'] as Map<String, dynamic>? ?? const {};
    return '${r[lang == 'gu' ? 'nameGu' : 'nameEn'] ?? ''}';
  }
}

final myRepMessagesProvider = FutureProvider.autoDispose<List<MyRepMessage>>((
  ref,
) async {
  final res = await ref.watch(apiClientProvider).getJson('/me/messages');
  return [
    for (final i in (res['items'] as List? ?? const []))
      MyRepMessage(i as Map<String, dynamic>),
  ];
});

/// `/me/messages`: the citizen's relayed messages with status and reply text.
class MyMessagesScreen extends ConsumerWidget {
  const MyMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final locale = Localizations.localeOf(context).languageCode;
    final async = ref.watch(myRepMessagesProvider);
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.repMsgMineTitle),
      body: async.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) {
          void retry() => ref.invalidate(myRepMessagesProvider);
          return AppError.from(e).isOffline
              ? OfflineState(onRetry: retry)
              : ErrorState(message: l10n.repMsgLoadError, onRetry: retry);
        },
        data: (items) => items.isEmpty
            ? EmptyState(message: l10n.repMsgMineEmpty)
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.s12),
                itemBuilder: (_, i) {
                  final m = items[i];
                  final replied = m.status == 'replied' && m.reply != null;
                  return Container(
                    key: Key('myMsg.${m.id}'),
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: AppRadii.cardRadius,
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.subject, style: text.titleMedium),
                        Text(m.repName(lang), style: text.bodySmall),
                        const SizedBox(height: AppSpacing.s8),
                        if (replied) ...[
                          Text(
                            (m.byEmail
                                ? l10n.repMsgRepliedEmail
                                : l10n.repMsgRepliedApp)(
                              Formatters.date(m.repliedAt!, locale),
                            ),
                            style: text.labelMedium,
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          Text(m.reply!, style: text.bodyMedium),
                        ] else
                          Text(
                            l10n.repMsgAwaiting,
                            style: text.bodyMedium?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
