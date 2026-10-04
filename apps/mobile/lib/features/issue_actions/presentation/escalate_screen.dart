import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/escalation.dart';
import '../application/issue_providers.dart';
import '../data/issue_actions_api.dart';
import 'common.dart';

String escalationLevelLabel(AppLocalizations l10n, String level) =>
    switch (level) {
      'zone_office' => l10n.issueActionsLevelZoneOffice,
      'deputy_commissioner' => l10n.issueActionsLevelDmc,
      'commissioner' => l10n.issueActionsLevelCommissioner,
      _ => l10n.issueActionsLevelCorporators,
    };

/// `/issues/:id/escalate` (TASK-06 §5.4, REQ-F-025): the 4-level ladder with
/// the suggested level tagged; choosing a level prepares the message (and
/// logs the escalation); actions per target plus Copy and Share. Always
/// shows that Saarthee is independent and this is not an official complaint.
class EscalateScreen extends ConsumerStatefulWidget {
  const EscalateScreen({super.key, required this.issueId});

  final String issueId;

  @override
  ConsumerState<EscalateScreen> createState() => _EscalateScreenState();
}

class _EscalateScreenState extends ConsumerState<EscalateScreen> {
  String? _level;
  EscalationDraft? _draft;
  bool _loading = false;
  String? _error;

  Future<void> _prepare(String level) async {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode == 'gu'
        ? 'gu'
        : 'en';
    setState(() {
      _level = level;
      _loading = true;
      _error = null;
      _draft = null;
    });
    try {
      final d = await ref
          .read(issueActionsApiProvider)
          .escalate(widget.issueId, level, lang);
      if (!mounted) return;
      setState(() => _draft = d);
      refreshIssue(ref, widget.issueId);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = lifecycleErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _fullText =>
      _draft == null ? '' : '${_draft!.subject}\n\n${_draft!.message}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final issue = ref.watch(issueLifecycleProvider(widget.issueId)).value;
    final events =
        ref.watch(issueEventsProvider(widget.issueId)).value ?? const [];
    final suggested = recommendedEscalation(
      events,
      overdue: issue?.isOverdue ?? false,
      now: DateTime.now(),
    );
    final launcher = ref.read(escalationLauncherProvider);
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.issueActionsEscalateTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          const NoticeBanner(kind: NoticeKind.independence, rounded: true),
          const SizedBox(height: AppSpacing.s8),
          Text(
            l10n.issueActionsEscalateNote,
            key: const Key('escalate.note'),
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.s16),
          for (final level in escalationLevels)
            ListTile(
              key: ValueKey('escalate.level.$level'),
              contentPadding: EdgeInsets.zero,
              minTileHeight: AppSpacing.touchTarget,
              leading: Icon(
                _level == level
                    ? SaartheeIcons.radioOn
                    : SaartheeIcons.radioOff,
                color: _level == level ? c.primary : c.textSecondary,
              ),
              title: Text(
                escalationLevelLabel(l10n, level),
                style: text.bodyLarge,
              ),
              trailing: level == suggested
                  ? TagLabel(
                      key: const Key('escalate.suggested'),
                      label: l10n.issueActionsSuggested,
                      icon: SaartheeIcons.check,
                      foreground: c.primary,
                      background: c.primaryContainer,
                    )
                  : null,
              onTap: _loading ? null : () => _prepare(level),
            ),
          const SizedBox(height: AppSpacing.s16),
          if (_loading) const SkeletonList(count: 2),
          if (_error != null)
            ErrorState(
              message: _error!,
              onRetry: () => _prepare(_level ?? suggested),
            ),
          if (draft != null) ...[
            Text(l10n.issueActionsMessagePreview, style: text.titleSmall),
            const SizedBox(height: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: AppRadii.cardRadius,
              ),
              child: SelectableText(
                _fullText,
                key: const Key('escalate.message'),
                style: text.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            for (final t in draft.targets)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: SecondaryButton(
                  key: ValueKey('escalate.target.${t.kind}.${t.label}'),
                  icon: t.kind == 'relay'
                      ? SaartheeIcons.message
                      : t.kind == 'email'
                      ? SaartheeIcons.openInNew
                      : SaartheeIcons.call,
                  label: switch (t.kind) {
                    'relay' => l10n.issueActionsMessageCorporator(t.label),
                    'email' => l10n.issueActionsEmailTarget(t.label),
                    _ => l10n.issueActionsCallTarget(t.label),
                  },
                  onPressed: () async {
                    if (t.kind == 'relay') {
                      await launcher.copy(_fullText);
                      if (context.mounted) {
                        context.push(
                          '/representatives/${t.representativeId}/message?issueId=${widget.issueId}',
                        );
                      }
                    } else if (t.kind == 'email' && t.email != null) {
                      await launcher.email(
                        t.email!,
                        draft.subject,
                        draft.message,
                      );
                    } else if (t.phone != null) {
                      await launcher.call(t.phone!);
                    }
                  },
                ),
              ),
            SecondaryButton(
              key: const Key('escalate.copy'),
              icon: SaartheeIcons.copy,
              label: l10n.issueActionsCopyMessage,
              onPressed: () async {
                await launcher.copy(_fullText);
                if (context.mounted) {
                  showSaartheeToast(context, l10n.issueActionsCopied);
                }
              },
            ),
            const SizedBox(height: AppSpacing.s8),
            SecondaryButton(
              key: const Key('escalate.share'),
              icon: SaartheeIcons.share,
              label: l10n.issueActionsShare,
              onPressed: () => launcher.share(_fullText),
            ),
          ],
        ],
      ),
    );
  }
}
