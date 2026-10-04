import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/report_providers.dart';

/// `/issues/:id/link-ccrs` (TASK-05 §5.4, REQ-F-018): the reporter adds the
/// AMC complaint number they got after filing with AMC.
class LinkCcrsScreen extends ConsumerStatefulWidget {
  const LinkCcrsScreen({super.key, required this.issueId});

  final String issueId;

  @override
  ConsumerState<LinkCcrsScreen> createState() => _LinkCcrsScreenState();
}

class _LinkCcrsScreenState extends ConsumerState<LinkCcrsScreen> {
  final _number = TextEditingController();
  String _via = 'web';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final cleaned = _number.text.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.isEmpty) {
      setState(() => _error = l10n.linkCcrsRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(reportActionsProvider)
          .linkCcrs(widget.issueId, _number.text.trim(), _via);
      if (!mounted) return;
      showSaartheeToast(context, l10n.linkCcrsSaved);
      context.pop();
    } on AppError catch (e) {
      setState(
        () => _error = switch (e.code) {
          'CCRS_ALREADY_LINKED' => l10n.linkCcrsConflict,
          'VALIDATION_FAILED' => l10n.linkCcrsRequired,
          _ => appErrorMessage(l10n, e),
        },
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final offline = ref.watch(isOfflineProvider);
    final options = {
      'web': l10n.linkCcrsWeb,
      'whatsapp': l10n.linkCcrsWhatsapp,
      'phone': l10n.linkCcrsPhone,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.linkCcrsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          if (offline)
            const NoticeBanner(kind: NoticeKind.offline, rounded: true),
          LabeledTextField(
            fieldKey: const Key('linkCcrs.number'),
            label: l10n.linkCcrsField,
            helper: l10n.linkCcrsHelp,
            error: _error,
            controller: _number,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(l10n.linkCcrsHow, style: text.titleSmall),
          for (final e in options.entries)
            InkWell(
              key: ValueKey('linkCcrs.via.${e.key}'),
              onTap: () => setState(() => _via = e.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                child: Row(
                  children: [
                    Icon(
                      _via == e.key
                          ? SaartheeIcons.radioOn
                          : SaartheeIcons.radioOff,
                      color: _via == e.key ? c.primary : c.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Text(e.value, style: text.bodyLarge),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.s24),
          PrimaryButton(
            key: const Key('linkCcrs.save'),
            label: l10n.linkCcrsSave,
            isLoading: _saving,
            onPressed: offline || _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
