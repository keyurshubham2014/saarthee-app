import 'package:flutter/material.dart';

import '../../../../core/theme/icons.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/admin_complaints.dart';
import '../../application/admin_reference.dart';
import '../../data/admin_api_error.dart';
import '../../data/models/reference_data.dart';
import '../admin_format.dart';
import '../admin_l10n.dart';
import '../shell/admin_session_guard.dart';
import '../widgets/admin_tokens.dart';
import '../widgets/admin_widgets.dart';

/// `/admin/invite-codes` (02 §4.22, TASK-09).
class AdminInviteCodesScreen extends ConsumerStatefulWidget {
  const AdminInviteCodesScreen({super.key});

  @override
  ConsumerState<AdminInviteCodesScreen> createState() =>
      _AdminInviteCodesScreenState();
}

class _AdminInviteCodesScreenState
    extends ConsumerState<AdminInviteCodesScreen> {
  final Set<String> _busy = <String>{};

  Future<void> _toggle(InviteCode code) async {
    final l10n = adminL10n(context);
    setState(() => _busy.add(code.id));
    try {
      await ref
          .read(adminReferenceActionsProvider)
          .setInviteCodeActive(code.id, isActive: !code.isActive);
      if (mounted) {
        showAdminSnack(context, l10n.adminSaved);
      }
    } on AdminApiError catch (e) {
      if (mounted && !e.isSessionEnded) {
        showAdminSnack(context, adminErrorMessage(l10n, e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(code.id));
      }
    }
  }

  Future<void> _share(InviteCode code) async {
    final l10n = adminL10n(context);
    // No share-sheet package in the app: copy the ready-made message.
    await Clipboard.setData(
      ClipboardData(text: l10n.adminShareCodeMessage(code.code)),
    );
    if (mounted) {
      showAdminSnack(context, l10n.adminCodeShareCopied);
    }
  }

  Future<void> _newCode() async {
    final l10n = adminL10n(context);
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _NewCodeSheet(),
    );
    if (created == true && mounted) {
      showAdminSnack(context, l10n.adminCodeCreated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    final tokens = AdminTokens.of(context);
    final codes = ref.watch(inviteCodesProvider);

    Widget body;
    if (codes.hasValue) {
      final items = codes.requireValue;
      body = items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                AdminEmptyState(
                  icon: SaartheeIcons.qrCode,
                  message: l10n.adminInviteCodesEmpty,
                  actionLabel: l10n.adminNewCode,
                  onAction: _newCode,
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: adminScreenPadding,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final c = items[i];
                final busy = _busy.contains(c.id);
                return Card(
                  key: Key('adminInviteCode-${c.code}'),
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(c.code, style: theme.textTheme.titleMedium),
                        Text(c.groupLabel, style: theme.textTheme.bodyMedium),
                        if (c.wardHint != null)
                          Text(c.wardHint!, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: <Widget>[
                            AdminTag(
                              icon: SaartheeIcons.group,
                              label: sourceLabel(l10n, c.sourceTag),
                              background: tokens.accentTint,
                              foreground: tokens.text,
                            ),
                            AdminTag(
                              icon: c.isActive
                                  ? SaartheeIcons.success
                                  : SaartheeIcons.pauseCircle,
                              label: c.isActive
                                  ? l10n.adminActive
                                  : l10n.adminInactive,
                              background: c.isActive
                                  ? tokens.fixedTint
                                  : tokens.neutralTint,
                              foreground: tokens.text,
                            ),
                            Text(
                              l10n.adminInviteCodeComplaints(c.complaintCount),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: <Widget>[
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: busy ? null : () => _toggle(c),
                              icon: Icon(
                                c.isActive
                                    ? SaartheeIcons.pause
                                    : SaartheeIcons.play,
                              ),
                              label: Text(
                                c.isActive
                                    ? l10n.adminDeactivate
                                    : l10n.adminActivate,
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () => _share(c),
                              icon: const Icon(SaartheeIcons.share),
                              label: Text(l10n.adminShare),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
    } else if (codes.hasError) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          AdminErrorView(
            title: l10n.adminInviteCodesLoadFailed,
            error: asAdminError(codes.error!),
            onRetry: () => ref.invalidate(inviteCodesProvider),
          ),
        ],
      );
    } else {
      body = const AdminSkeletonList(height: 120);
    }

    return AdminSessionGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.adminInviteCodesTitle)),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('adminNewCode'),
          onPressed: _newCode,
          icon: const Icon(SaartheeIcons.add),
          label: Text(l10n.adminNewCode),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(inviteCodesProvider.future),
            child: AdminContentWidth(child: body),
          ),
        ),
      ),
    );
  }
}

class _NewCodeSheet extends ConsumerStatefulWidget {
  const _NewCodeSheet();

  @override
  ConsumerState<_NewCodeSheet> createState() => _NewCodeSheetState();
}

class _NewCodeSheetState extends ConsumerState<_NewCodeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _group = TextEditingController();
  final _ward = TextEditingController();
  final _code = TextEditingController();
  String _source = assignableSourceTags.first;
  bool _busy = false;
  String? _codeError;
  AdminApiError? _error;

  @override
  void dispose() {
    _group.dispose();
    _ward.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = adminL10n(context);
    setState(() {
      _codeError = null;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(adminReferenceActionsProvider)
          .createInviteCode(
            code: _code.text,
            sourceTag: _source,
            groupLabel: _group.text,
            wardHint: _ward.text,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AdminApiError catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (e.code == AdminErrorCodes.inviteCodeTaken ||
            e.fieldErrors.containsKey('code')) {
          _codeError = l10n.adminCodeInvalid;
        } else {
          _error = e;
        }
      });
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.adminNewCodeTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_error != null) ...<Widget>[
                AdminMessageBanner(message: adminErrorMessage(l10n, _error!)),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                key: const Key('adminNewCodeSource'),
                initialValue: _source,
                decoration: InputDecoration(
                  labelText: l10n.adminSourceTagLabel,
                  border: const OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String>>[
                  for (final tag in assignableSourceTags)
                    DropdownMenuItem<String>(
                      value: tag,
                      child: Text(sourceLabel(l10n, tag)),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _source = v ?? _source),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('adminNewCodeGroup'),
                controller: _group,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: l10n.adminGroupLabelLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? l10n.adminGroupLabelRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('adminNewCodeWard'),
                controller: _ward,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: l10n.adminWardHintLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('adminNewCodeCustom'),
                controller: _code,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.adminCustomCodeLabel,
                  helperText: l10n.adminCustomCodeHelp,
                  helperMaxLines: 2,
                  errorText: _codeError,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) {
                    return null;
                  }
                  return RegExp(r'^[A-Za-z0-9]{6,20}$').hasMatch(text)
                      ? null
                      : l10n.adminCodeInvalid;
                },
              ),
              const SizedBox(height: 20),
              AdminPrimaryButton(
                key: const Key('adminNewCodeSubmit'),
                label: l10n.adminCreate,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
