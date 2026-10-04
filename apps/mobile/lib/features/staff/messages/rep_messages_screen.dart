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

final repMessagesProvider = FutureProvider.autoDispose<Json>(
  (ref) => ref.watch(repConsoleApiProvider).messages(),
);
final repMessageProvider = FutureProvider.autoDispose.family<Json, String>(
  (ref, id) => ref.watch(repConsoleApiProvider).message(id),
);

String _label(Json m, String lang) =>
    '${(m['citizenLabel'] as Json?)?[lang == 'gu' ? 'gu' : 'en'] ?? ''}';

/// `/staff/messages` (TASK-11 P2): relayed messages, unread dot, citizen as
/// "A resident of {ward}", status chip Sent / Replied.
class RepMessagesScreen extends ConsumerWidget {
  const RepMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    return StaffAsync<Json>(
      value: ref.watch(repMessagesProvider),
      onRetry: () => ref.invalidate(repMessagesProvider),
      builder: (j) {
        final items = (j['items'] as List? ?? const []).cast<Json>();
        if (items.isEmpty) return EmptyState(message: l10n.repMsgEmpty);
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            StaffCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final m in items)
                    ListRow(
                      key: Key('repMsg.row.${m['id']}'),
                      leading: m['readByRepAt'] == null
                          ? Semantics(
                              label: l10n.repMsgUnread,
                              child: Icon(
                                SaartheeIcons.radioOn,
                                key: Key('repMsg.unread.${m['id']}'),
                                size: AppSpacing.iconSmall,
                                color: c.primary,
                              ),
                            )
                          : const SizedBox(width: AppSpacing.iconSmall),
                      title: jsonText(m, 'subject'),
                      subtitle: _label(m, lang),
                      trailing: Text(
                        m['status'] == 'replied'
                            ? l10n.repMsgStatusReplied
                            : l10n.repMsgStatusSent,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      onTap: () async {
                        await context.push('/staff/messages/${m['id']}');
                        ref.invalidate(repMessagesProvider);
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// `/staff/messages/:id`: body, shared phone (opt-in only), reply field
/// (2,000 chars) or "Replied by email on {date}".
class RepMessageDetailScreen extends ConsumerStatefulWidget {
  const RepMessageDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<RepMessageDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<RepMessageDetailScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    if (_reply.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(repConsoleApiProvider)
          .reply(widget.id, _reply.text.trim());
      ref.invalidate(repMessageProvider(widget.id));
      if (mounted) showSaartheeToast(context, l10n.repMsgReplySent);
    } catch (e) {
      if (mounted) {
        showSaartheeToast(
          context,
          repErrorMessage(l10n, e),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    final locale = Localizations.localeOf(context).languageCode;
    return StaffAsync<Json>(
      value: ref.watch(repMessageProvider(widget.id)),
      onRetry: () => ref.invalidate(repMessageProvider(widget.id)),
      builder: (m) {
        final repliedAt = DateTime.tryParse('${m['repliedAt']}');
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            Text(jsonText(m, 'subject'), style: text.titleLarge),
            Text(_label(m, lang), style: text.bodySmall),
            if (m['sharedPhone'] != null)
              Text(
                l10n.repMsgSharedPhone('${m['sharedPhone']}'),
                key: const Key('repMsg.phone'),
              ),
            const SizedBox(height: AppSpacing.s12),
            StaffCard(child: Text(jsonText(m, 'body'), style: text.bodyLarge)),
            const SizedBox(height: AppSpacing.s16),
            if (repliedAt != null) ...[
              Text(
                m['replyChannel'] == 'email'
                    ? l10n.repMsgRepliedEmail(
                        Formatters.date(repliedAt, locale),
                      )
                    : l10n.repMsgRepliedApp(Formatters.date(repliedAt, locale)),
                key: const Key('repMsg.replied'),
                style: text.labelLarge,
              ),
              if (m['reply'] != null)
                Text(jsonText(m, 'reply'), style: text.bodyMedium),
            ] else ...[
              TextField(
                key: const Key('repMsg.replyField'),
                controller: _reply,
                maxLength: 2000,
                maxLines: 6,
                decoration: InputDecoration(labelText: l10n.repMsgReplyLabel),
              ),
              PrimaryButton(
                key: const Key('repMsg.send'),
                label: l10n.repMsgReplySend,
                isLoading: _sending,
                onPressed: _send,
              ),
            ],
          ],
        );
      },
    );
  }
}
