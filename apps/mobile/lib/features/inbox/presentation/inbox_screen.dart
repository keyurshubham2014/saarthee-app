import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/push/push_route.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/alerts/validity_format.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/ensure_signed_in.dart';
import '../../auth/application/session_controller.dart';
import '../application/inbox_controller.dart';
import '../data/inbox_models.dart';
import 'inbox_row.dart';

/// `/me/notifications` (REQ-F-040): Today / Earlier, unread bold with a dot,
/// tap opens the target and marks read, swipe or TalkBack action marks read,
/// "Mark all as read". Failed updates roll back with a toast (AC-17).
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        showSaartheeToast(
          context,
          l10n.inboxUpdateError,
          kind: ToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final inbox = ref.watch(inboxProvider);
    final unread = ref.watch(inboxUnreadCountProvider);
    return Scaffold(
      appBar: SaartheeAppBar(
        title: l10n.inboxTitle,
        showLanguageToggle: false,
        actions: [
          if (signedIn && unread > 0)
            TextButton(
              key: const ValueKey('inboxMarkAll'),
              onPressed: () =>
                  _run(context, ref.read(inboxProvider.notifier).markAllRead),
              child: Text(l10n.inboxMarkAll),
            ),
        ],
      ),
      body: !signedIn
          ? EmptyState(
              message: l10n.inboxSignedOut,
              icon: SaartheeIcons.notifications,
              actionLabel: l10n.inboxSignIn,
              onAction: () =>
                  ensureSignedIn(context, ref, reason: SignInReason.generic),
            )
          : inbox.when(
              loading: () => const SkeletonList(count: 6),
              error: (_, _) => ErrorState(
                message: l10n.inboxError,
                onRetry: () => ref.invalidate(inboxProvider),
              ),
              data: (page) => page.items.isEmpty
                  ? EmptyState(
                      message: l10n.inboxEmpty,
                      icon: SaartheeIcons.notifications,
                    )
                  : _List(page: page, run: (a) => _run(context, a)),
            ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.page, required this.run});

  final InboxPage page;
  final void Function(Future<void> Function()) run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final text = Theme.of(context).textTheme;
    final ctrl = ref.read(inboxProvider.notifier);
    final today = page.items.where((i) => isIstToday(i.createdAt)).toList();
    final earlier = page.items.where((i) => !isIstToday(i.createdAt)).toList();
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.s16,
        AppSpacing.gutter,
        AppSpacing.s8,
      ),
      child: Semantics(header: true, child: Text(t, style: text.titleSmall)),
    );
    Widget row(InboxItem i) => InboxRow(
      key: ValueKey('inbox.${i.id}'),
      item: i,
      lang: lang,
      onMarkRead: () => run(() => ctrl.markRead(i.id)),
      onOpen: () {
        run(() => ctrl.markRead(i.id));
        final target = safePushRoute(i.route);
        if (target == '/me/notifications' || target == '/') {
          showSaartheeToast(context, l10n.inboxGone, kind: ToastKind.info);
          return;
        }
        unawaited(context.push(target));
      },
    );
    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      child: ListView(
        children: [
          if (today.isNotEmpty) header(l10n.inboxToday),
          ...today.map(row),
          if (earlier.isNotEmpty) header(l10n.inboxEarlier),
          ...earlier.map(row),
        ],
      ),
    );
  }
}
