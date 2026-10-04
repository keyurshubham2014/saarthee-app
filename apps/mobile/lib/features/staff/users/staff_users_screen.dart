import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/staff_api.dart';
import '../shared/staff_shared.dart';
import '../shared/staff_widgets.dart';
import '../shell/staff_motion.dart';
import '../shell/staff_nav_labels.dart';
import '../shell/staff_session.dart';

class StaffUser {
  const StaffUser({
    required this.id,
    required this.name,
    required this.phoneMasked,
    required this.role,
    required this.status,
  });

  factory StaffUser.fromJson(Json j) => StaffUser(
    id: '${j['id']}',
    name: j['displayName'] as String?,
    phoneMasked: j['phoneMasked'] as String?,
    role: '${j['role']}',
    status: '${j['status']}',
  );

  final String id, role, status;
  final String? name, phoneMasked;
}

class _UsersQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String q) => state = q;
}

final staffUsersQueryProvider =
    NotifierProvider.autoDispose<_UsersQuery, String>(_UsersQuery.new);

final staffUsersProvider = FutureProvider.autoDispose<List<StaffUser>>((
  ref,
) async {
  final q = ref.watch(staffUsersQueryProvider);
  final j = await ref.watch(staffApiProvider).users(q: q);
  return [
    for (final u in (j['items'] as List))
      StaffUser.fromJson((u as Map).cast<String, dynamic>()),
  ];
});

/// Users & roles (TASK-10 §5.4): search by name or last 4 digits; masked
/// phones only; own row actions disabled.
class StaffUsersScreen extends ConsumerStatefulWidget {
  const StaffUsersScreen({super.key});

  @override
  ConsumerState<StaffUsersScreen> createState() => _StaffUsersScreenState();
}

class _StaffUsersScreenState extends ConsumerState<StaffUsersScreen> {
  final _search = TextEditingController();
  String? _busy;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _act(String id, Future<void> Function(StaffApi api) call) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = id);
    try {
      await call(ref.read(staffApiProvider));
      if (mounted) showStaffToast(context, l10n.staffDone);
    } catch (e) {
      if (mounted) {
        showStaffToast(context, staffErrorText(l10n, e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
      ref.invalidate(staffUsersProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(staffMeProvider).value;
    return StaffPageScaffold(
      title: l10n.staffUsersTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: TextField(
              key: const Key('staff.users.search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: l10n.staffUsersSearch,
                prefixIcon: const Icon(SaartheeIcons.search),
              ),
              onSubmitted: (v) =>
                  ref.read(staffUsersQueryProvider.notifier).set(v.trim()),
            ),
          ),
          Expanded(
            child: StaffAsync<List<StaffUser>>(
              value: ref.watch(staffUsersProvider),
              onRetry: () => ref.invalidate(staffUsersProvider),
              builder: (users) => users.isEmpty
                  ? EmptyState(
                      key: const Key('staff.users.empty'),
                      icon: SaartheeIcons.searchOff,
                      message: l10n.staffUsersEmpty,
                    )
                  : ListView(
                      children: [
                        for (final u in users)
                          _row(context, u, self: u.id == me?.actorId),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, StaffUser u, {required bool self}) {
    final l10n = AppLocalizations.of(context);
    final suspended = u.status == 'suspended';
    final canRole = !self && (u.role == 'citizen' || u.role == 'moderator');
    Widget action(String id, String label, VoidCallback onPressed) =>
        TextButton(
          key: Key('staff.users.${u.id}.$id'),
          onPressed: _busy == null && !self ? onPressed : null,
          child: Text(label),
        );
    final actions = Wrap(
      spacing: AppSpacing.s4,
      children: [
        if (canRole)
          action(
            'role',
            u.role == 'moderator'
                ? l10n.staffUsersRemoveMod
                : l10n.staffUsersMakeMod,
            () => _act(
              u.id,
              (api) => api.setRole(
                u.id,
                u.role == 'moderator' ? 'citizen' : 'moderator',
              ),
            ),
          ),
        action(
          'status',
          suspended ? l10n.staffUsersReinstate : l10n.staffUsersSuspend,
          () async {
            final reason = await askStaffReason(
              context,
              title: suspended
                  ? l10n.staffUsersReinstate
                  : l10n.staffUsersSuspend,
              effect: suspended ? null : l10n.staffIssueConfirmSuspend,
            );
            if (reason != null) {
              await _act(
                u.id,
                (api) => api.suspend(u.id, reason, suspend: !suspended),
              );
            }
          },
        ),
      ],
    );
    return ListRow(
      key: Key('staff.users.${u.id}'),
      showChevron: false,
      leading: Icon(suspended ? SaartheeIcons.personOff : SaartheeIcons.person),
      title: u.name ?? l10n.staffUsersNoName,
      subtitle: [
        u.phoneMasked ?? '',
        staffRoleLabel(l10n, u.role),
        suspended ? l10n.staffUsersSuspended : l10n.staffUsersActive,
      ].where((s) => s.isNotEmpty).join(' · '),
      trailing: self
          ? Tooltip(message: l10n.staffUsersSelf, child: actions)
          : actions,
    );
  }
}
