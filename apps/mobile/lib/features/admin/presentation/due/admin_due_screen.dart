import 'package:flutter/material.dart';

import '../../../../core/theme/icons.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_l10n.dart';
import '../../application/admin_complaints.dart';
import '../../data/models/complaint_summary.dart';
import '../admin_paths.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/complaint_list_item.dart';
import 'reminder_sheet.dart';

/// `/admin` Due tab (02 §4.18).
class AdminDueScreen extends ConsumerWidget {
  const AdminDueScreen({super.key});

  static const _filter = ComplaintFilter.dueOnly;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dueCountProvider);
    await ref.read(adminComplaintsProvider(_filter).notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = adminL10n(context);
    final state = ref.watch(adminComplaintsProvider(_filter));
    final sending = ref.watch(reminderSenderProvider);
    final notifier = ref.read(adminComplaintsProvider(_filter).notifier);

    Widget body;
    if (!state.loaded && state.loading) {
      body = const AdminSkeletonList();
    } else if (!state.loaded && state.error != null) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          AdminErrorView(
            title: l10n.adminListLoadFailed,
            error: state.error!,
            onRetry: () => _refresh(ref),
          ),
        ],
      );
    } else if (state.items.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          if (state.error != null)
            Padding(
              padding: adminScreenPadding,
              child: AdminErrorView(
                error: state.error!,
                onRetry: () => _refresh(ref),
              ),
            ),
          AdminEmptyState(
            key: const Key('adminDueEmpty'),
            icon: SaartheeIcons.taskAlt,
            message: l10n.adminDueEmpty,
          ),
        ],
      );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
            notifier.loadMore();
          }
          return false;
        },
        child: ListView.separated(
          key: const Key('adminDueList'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: adminScreenPadding,
          itemCount: state.items.length + 1 + (state.error != null ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            var i = index;
            if (state.error != null) {
              if (i == 0) {
                return AdminMessageBanner(
                  message: l10n.adminListLoadFailed,
                  onRetry: () => _refresh(ref),
                );
              }
              i -= 1;
            }
            if (i == state.items.length) {
              return LoadMoreFooter(state: state, onRetry: notifier.loadMore);
            }
            final c = state.items[i];
            return ComplaintListItem(
              key: Key('adminDueItem-${c.id}'),
              complaint: c,
              onTap: () => context.push(AdminPaths.complaint(c.id)),
              action: AdminPrimaryButton(
                key: Key('adminSendReminder-${c.id}'),
                icon: SaartheeIcons.send,
                label: l10n.adminSendReminder,
                busy: sending.contains(c.id),
                onPressed: () => sendReminderFlow(context, ref, c.id),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminDueTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: AdminContentWidth(child: body),
        ),
      ),
    );
  }
}
