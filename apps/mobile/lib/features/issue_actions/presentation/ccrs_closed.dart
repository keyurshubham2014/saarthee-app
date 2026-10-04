import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../application/escalation.dart';
import '../application/issue_providers.dart';
import '../data/issue_actions_api.dart';
import 'common.dart';

/// AMC's complaint portal (where the citizen reopens a CCRS complaint).
const amcComplaintSiteUrl = 'https://www.amccrs.com/AMCPortal/';

/// "Did AMC close your complaint?" sheet (TASK-06 §5.4, REQ-F-026). Only
/// offered to the reporter with a linked CCRS number.
Future<void> showCcrsClosedSheet(BuildContext context, String issueId) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _CcrsClosedSheet(issueId: issueId),
    );

class _CcrsClosedSheet extends ConsumerStatefulWidget {
  const _CcrsClosedSheet({required this.issueId});
  final String issueId;

  @override
  ConsumerState<_CcrsClosedSheet> createState() => _CcrsClosedSheetState();
}

class _CcrsClosedSheetState extends ConsumerState<_CcrsClosedSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _yes() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(issueActionsApiProvider).ccrsClosed(widget.issueId);
      if (!mounted) return;
      refreshIssue(ref, widget.issueId);
      Navigator.of(context).pop();
    } on AppError catch (e) {
      if (mounted) setState(() => _error = lifecycleErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.issueActionsCcrsQuestion,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s16),
            PrimaryButton(
              key: const Key('ccrsClosed.yes'),
              label: l10n.issueActionsCcrsYes,
              isLoading: _saving,
              onPressed: _yes,
            ),
            if (_error != null) InlineFieldError(message: _error!),
          ],
        ),
      ),
    );
  }
}

/// Banner after "AMC closed it": reopen deadline (closed + 24 h) with
/// "Open AMC site" and "It's fixed — verify".
class CcrsClosedBanner extends ConsumerWidget {
  const CcrsClosedBanner({
    super.key,
    required this.issueId,
    required this.deadline,
    this.canVerify = false,
  });

  final String issueId;
  final DateTime deadline;
  final bool canVerify;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = Formatters.dateTime(deadline, locale);
    return Container(
      key: const Key('ccrsClosed.banner'),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: c.warningTint,
        borderRadius: AppRadii.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.issueActionsCcrsBanner(time),
              key: const Key('ccrsClosed.text'),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          TertiaryButton(
            key: const Key('ccrsClosed.openSite'),
            icon: SaartheeIcons.openInNew,
            label: l10n.issueActionsCcrsOpenSite,
            onPressed: () => ref
                .read(escalationLauncherProvider)
                .openUrl(amcComplaintSiteUrl),
          ),
          if (canVerify)
            TertiaryButton(
              key: const Key('ccrsClosed.verify'),
              label: l10n.issueActionsCcrsVerify,
              onPressed: () => context.push('/issues/$issueId/verify'),
            ),
        ],
      ),
    );
  }
}
