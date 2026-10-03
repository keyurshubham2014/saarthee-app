import 'package:flutter/material.dart';

import '../../../../core/theme/icons.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_l10n.dart';
import '../../application/admin_auth.dart';
import '../../data/admin_api_error.dart';
import '../admin_format.dart';
import '../admin_paths.dart';
import '../widgets/admin_widgets.dart';

/// `/admin/more`: reference data links, log out, log out everywhere.
class AdminMoreScreen extends ConsumerStatefulWidget {
  const AdminMoreScreen({super.key});

  @override
  ConsumerState<AdminMoreScreen> createState() => _AdminMoreScreenState();
}

class _AdminMoreScreenState extends ConsumerState<AdminMoreScreen> {
  bool _busy = false;
  AdminApiError? _error;

  Future<void> _logoutEverywhere() async {
    final l10n = adminL10n(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adminLogoutEverywhereTitle),
        content: Text(l10n.adminLogoutEverywhereBody),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.adminCancel),
          ),
          FilledButton(
            key: const Key('adminLogoutEverywhereConfirm'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.adminLogoutEverywhere),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminAuthProvider.notifier).logoutEverywhere();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminLoggedOutEverywhere)),
      );
    } on AdminApiError catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    final admin = ref.watch(adminAuthProvider).session?.admin;
    Widget link(IconData icon, String label, String path, String key) =>
        ListTile(
          key: Key(key),
          minTileHeight: 56,
          leading: Icon(icon),
          title: Text(label),
          trailing: const Icon(SaartheeIcons.chevronRight),
          onTap: () => context.push(path),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminMoreTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: <Widget>[
            if (admin != null)
              Padding(
                padding: adminScreenPadding,
                child: Text(
                  l10n.adminMoreSignedInAs(
                    admin.displayName.isEmpty ? admin.email : admin.displayName,
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            link(
              SaartheeIcons.qrCode,
              l10n.adminMoreInviteCodes,
              AdminPaths.inviteCodes,
              'adminMoreInviteCodes',
            ),
            link(
              SaartheeIcons.category,
              l10n.adminMoreCategories,
              AdminPaths.categories,
              'adminMoreCategories',
            ),
            link(
              SaartheeIcons.download,
              l10n.adminMoreExport,
              AdminPaths.export,
              'adminMoreExport',
            ),
            const Divider(height: 32),
            Padding(
              padding: adminScreenPadding,
              child: Column(
                children: <Widget>[
                  if (_error != null) ...<Widget>[
                    AdminMessageBanner(
                      message: adminErrorMessage(l10n, _error!),
                      onRetry: _busy ? null : _logoutEverywhere,
                    ),
                    const SizedBox(height: 16),
                  ],
                  AdminSecondaryButton(
                    key: const Key('adminLogout'),
                    icon: SaartheeIcons.logout,
                    label: l10n.adminLogout,
                    onPressed: _busy
                        ? null
                        : () => ref.read(adminAuthProvider.notifier).logout(),
                  ),
                  const SizedBox(height: 12),
                  AdminSecondaryButton(
                    key: const Key('adminLogoutEverywhere'),
                    icon: SaartheeIcons.devices,
                    label: l10n.adminLogoutEverywhere,
                    busy: _busy,
                    onPressed: _logoutEverywhere,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
