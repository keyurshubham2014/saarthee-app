import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/ensure_signed_in.dart';
import '../../auth/application/phone_sign_in.dart';
import '../../auth/data/account_models.dart';
import '../../onboarding/presentation/ward_picker_sheet.dart';
import '../application/me_controller.dart';
import 'display_name_editor.dart';

/// `/me` (replaces P-09, TASK-04 §5.4). Signed out: a "Sign in" row with the
/// reason. Signed in: display name (editable), masked phone, home ward,
/// language, and links to Privacy, Settings and Sign out.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider);
    final offline = ref.watch(isOfflineProvider);
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.accountTitle),
      body: Column(
        children: [
          if (offline)
            NoticeBanner(
              kind: NoticeKind.offline,
              message: l10n.accountOfflineReadOnly,
            ),
          Expanded(
            child: me.when(
              loading: () => const SkeletonList(count: 4),
              error: (e, _) => ErrorState(
                message: authErrorText(l10n, e),
                onRetry: () => ref.invalidate(meProvider),
              ),
              data: (m) => m == null
                  ? const _SignedOut()
                  : _Profile(me: m, readOnly: offline),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedOut extends ConsumerWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    return ListView(
      children: [
        ListRow(
          key: const Key('me.signIn'),
          leading: Icon(SaartheeIcons.person, color: c.primary),
          title: l10n.accountSignInRow,
          subtitle: l10n.accountSignInWhy,
          onTap: () =>
              ensureSignedIn(context, ref, reason: SignInReason.profile),
        ),
        ListRow(
          key: const Key('me.settings'),
          leading: Icon(SaartheeIcons.settings, color: c.textSecondary),
          title: l10n.settingsTitle,
          onTap: () => context.push('/me/settings'),
        ),
      ],
    );
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({required this.me, required this.readOnly});

  final Me me;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final localWard = ref.watch(homeWardProvider);
    final wardNumber = me.homeWard?.number ?? localWard?.number;
    final wardName = lang == 'gu'
        ? me.homeWard?.nameGu ?? localWard?.nameGu
        : me.homeWard?.nameEn ?? localWard?.nameEn;
    final wardText = wardNumber == null
        ? l10n.accountNoWard
        : wardName == null
        ? l10n.accountWardNumber(wardNumber)
        : l10n.wardDisplayName(wardNumber, wardName);

    Future<void> changeWard() async {
      final picked = await showWardPicker(context);
      if (picked != null) {
        await ref.read(homeWardProvider.notifier).set(picked);
      }
      ref.invalidate(meProvider);
    }

    Future<void> signOut() async {
      await ref.read(meActionsProvider).signOut();
      if (context.mounted) {
        showSaartheeToast(context, l10n.accountSignedOut, kind: ToastKind.info);
      }
    }

    return ListView(
      key: const PageStorageKey('me.scroll'),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: DisplayNameEditor(initial: me.displayName, enabled: !readOnly),
        ),
        // TASK-10: staff roles reach the console from here.
        if (me.role != 'citizen')
          ListRow(
            key: const Key('me.staffTools'),
            leading: Icon(SaartheeIcons.adminPanel, color: c.textSecondary),
            title: l10n.staffToolsRow,
            onTap: () => context.push('/staff'),
          ),
        ListRow(
          key: const Key('me.phone'),
          leading: Icon(SaartheeIcons.lock, color: c.textSecondary),
          title: l10n.authPhoneLabel,
          subtitle: me.phoneMasked,
          showChevron: false,
        ),
        ListRow(
          key: const Key('me.ward'),
          leading: Icon(SaartheeIcons.navMyWard, color: c.textSecondary),
          title: l10n.accountHomeWard,
          subtitle: wardText,
          trailing: TextButton(
            onPressed: readOnly ? null : changeWard,
            child: Text(l10n.commonChange),
          ),
          showChevron: false,
        ),
        ListRow(
          key: const Key('me.language'),
          leading: Icon(SaartheeIcons.language, color: c.textSecondary),
          title: l10n.accountLanguage,
          subtitle: lang == 'gu'
              ? l10n.accountLanguageGu
              : l10n.accountLanguageEn,
          trailing: TextButton(
            key: const Key('me.language.toggle'),
            onPressed: readOnly
                ? null
                : () => ref.read(localeProvider.notifier).toggle(),
            child: Text(l10n.commonChange),
          ),
          showChevron: false,
        ),
        const Divider(),
        // TASK-07: My reports and Following.
        ListRow(
          key: const Key('me.reports'),
          leading: Icon(SaartheeIcons.report, color: c.textSecondary),
          title: l10n.discoveryMyReportsTitle,
          onTap: () => context.push('/me/reports'),
        ),
        ListRow(
          key: const Key('me.following'),
          leading: Icon(SaartheeIcons.follow, color: c.textSecondary),
          title: l10n.discoveryFollowingTitle,
          onTap: () => context.push('/me/following'),
        ),
        ListRow(
          key: const Key('me.privacy'),
          leading: Icon(SaartheeIcons.lock, color: c.textSecondary),
          title: l10n.accountPrivacyLink,
          onTap: () => context.push('/me/privacy'),
        ),
        ListRow(
          key: const Key('me.settings'),
          leading: Icon(SaartheeIcons.settings, color: c.textSecondary),
          title: l10n.settingsTitle,
          onTap: () => context.push('/me/settings'),
        ),
        ListRow(
          key: const Key('me.signOut'),
          leading: Icon(SaartheeIcons.logout, color: c.textSecondary),
          title: l10n.accountSignOut,
          showChevron: false,
          onTap: signOut,
        ),
        const SizedBox(height: AppSpacing.s24),
      ],
    );
  }
}
