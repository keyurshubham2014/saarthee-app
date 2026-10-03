import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/admin_reference.dart';
import '../../data/admin_api_error.dart';
import '../admin_format.dart';
import '../admin_l10n.dart';
import '../shell/admin_session_guard.dart';
import '../widgets/admin_widgets.dart';

/// `/admin/export` (02 §4.22, TASK-09).
class AdminExportScreen extends ConsumerStatefulWidget {
  const AdminExportScreen({super.key});

  @override
  ConsumerState<AdminExportScreen> createState() => _AdminExportScreenState();
}

class _AdminExportScreenState extends ConsumerState<AdminExportScreen> {
  String _type = 'complaints';
  bool _includePhone = false;
  bool _busy = false;
  AdminApiError? _error;
  String? _savedMessage;

  Future<void> _export() async {
    final l10n = adminL10n(context);
    setState(() {
      _busy = true;
      _error = null;
      _savedMessage = null;
    });
    try {
      final file = await ref
          .read(adminReferenceActionsProvider)
          .exportCsv(type: _type, includePhone: _includePhone);
      if (!mounted) {
        return;
      }
      final name = file.uri.pathSegments.last;
      setState(
        () => _savedMessage = l10n.adminExportSaved(name, file.parent.path),
      );
    } on AdminApiError catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    } on Exception {
      if (mounted) {
        setState(() => _error = const AdminApiError.unknown());
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
    final types = <(String, String)>[
      ('complaints', l10n.adminExportComplaints),
      ('verifications', l10n.adminExportVerifications),
      ('reminders', l10n.adminExportReminders),
    ];
    return AdminSessionGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.adminExportTitle)),
        body: SafeArea(
          child: AdminContentWidth(
            child: ListView(
              padding: adminScreenPadding,
              children: <Widget>[
                Text(
                  l10n.adminExportTypeLabel,
                  style: theme.textTheme.titleMedium,
                ),
                RadioGroup<String>(
                  groupValue: _type,
                  onChanged: (v) {
                    if (!_busy && v != null) {
                      setState(() => _type = v);
                    }
                  },
                  child: Column(
                    children: <Widget>[
                      for (final (value, label) in types)
                        RadioListTile<String>(
                          key: Key('adminExportType-$value'),
                          contentPadding: EdgeInsets.zero,
                          value: value,
                          title: Text(label),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const Key('adminExportIncludePhone'),
                  contentPadding: EdgeInsets.zero,
                  value: _includePhone,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _includePhone = v),
                  title: Text(l10n.adminExportIncludePhone),
                ),
                if (_includePhone)
                  AdminMessageBanner(
                    message: l10n.adminExportPhoneWarning,
                    icon: Icons.warning_amber_rounded,
                  ),
                const SizedBox(height: 24),
                if (_error != null) ...<Widget>[
                  AdminMessageBanner(
                    message: _error!.kind == AdminErrorKind.unknown
                        ? l10n.adminExportFailed
                        : adminErrorMessage(l10n, _error!),
                    onRetry: _busy ? null : _export,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_savedMessage != null) ...<Widget>[
                  AdminMessageBanner(
                    key: const Key('adminExportSaved'),
                    message: _savedMessage!,
                    icon: Icons.check_circle_rounded,
                    isError: false,
                  ),
                  const SizedBox(height: 12),
                ],
                AdminPrimaryButton(
                  key: const Key('adminExportButton'),
                  icon: Icons.download_rounded,
                  label: l10n.adminExportButton,
                  busy: _busy,
                  onPressed: _export,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
