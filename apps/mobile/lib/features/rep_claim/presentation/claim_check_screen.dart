import 'package:flutter/material.dart' hide ErrorSummary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../ward/application/ward_providers.dart';
import '../application/claim_draft.dart';
import '../data/rep_claim_api.dart';

/// `/representatives/:id/claim/check` — step 2 of 2: summary with Change
/// links, consent line, "Send claim"; errors in an [ErrorSummary] that takes
/// focus (409 pending adds "See my claims").
class ClaimCheckScreen extends ConsumerStatefulWidget {
  const ClaimCheckScreen({super.key, required this.repId});

  final String repId;

  @override
  ConsumerState<ClaimCheckScreen> createState() => _State();
}

class _State extends ConsumerState<ClaimCheckScreen> {
  bool _consent = false;
  bool _sending = false;
  String? _error;
  String? _code;

  Future<void> _send(String name) async {
    final l10n = AppLocalizations.of(context);
    if (!_consent) {
      setState(() {
        _error = l10n.repClaimConsentRequired;
        _code = null;
      });
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _code = null;
    });
    try {
      await ref.read(claimDraftProvider(widget.repId).notifier).submit();
      ref.read(claimDraftProvider(widget.repId).notifier).clear();
      ref.invalidate(myRepClaimsProvider);
      if (mounted) context.go('/representatives/${widget.repId}/claim/done');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = repErrorMessage(l10n, e);
        _code = AppError.from(e).code;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    final draft = ref.watch(claimDraftProvider(widget.repId));
    final rep = ref.watch(repDetailProvider(widget.repId)).value;
    final name = rep?.summary.name(lang) ?? '';
    void change() => context.pop();
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.repClaimCheckTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          Text(l10n.repClaimStep(2, 2), style: text.labelLarge),
          const SizedBox(height: AppSpacing.s12),
          if (_error != null) ...[
            ErrorSummary(
              key: const Key('repClaim.check.error'),
              items: [ErrorSummaryItem(_error!)],
            ),
            if (_code == 'CLAIM_ALREADY_PENDING')
              TextButton(
                key: const Key('repClaim.seeMine'),
                onPressed: () => context.go('/me'),
                child: Text(l10n.repClaimSeeMine),
              ),
            const SizedBox(height: AppSpacing.s12),
          ],
          ListRow(
            title: l10n.repClaimEvidenceRow,
            subtitle: l10n.repClaimPhotoCount(draft.photoIds.length),
            trailing: TextButton(
              onPressed: change,
              child: Text(l10n.repClaimChange),
            ),
            showChevron: false,
          ),
          ListRow(
            title: l10n.repClaimNoteRow,
            subtitle: draft.note.trim().isEmpty
                ? l10n.repClaimNoNote
                : draft.note,
            trailing: TextButton(
              onPressed: change,
              child: Text(l10n.repClaimChange),
            ),
            showChevron: false,
          ),
          const SizedBox(height: AppSpacing.s12),
          CheckboxListTile(
            key: const Key('repClaim.consent'),
            value: _consent,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: Text(l10n.repClaimConsent(name), style: text.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.s24),
          PrimaryButton(
            key: const Key('repClaim.send'),
            label: l10n.repClaimSend,
            isLoading: _sending,
            onPressed: draft.ready ? () => _send(name) : null,
          ),
        ],
      ),
    );
  }
}

/// `/representatives/:id/claim/done`.
class ClaimDoneScreen extends StatelessWidget {
  const ClaimDoneScreen({super.key, required this.repId});

  final String repId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.repClaimDoneTitle),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.repClaimDoneTitle, style: text.headlineSmall),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(l10n.repClaimDoneBody, style: text.bodyLarge),
            const Spacer(),
            PrimaryButton(
              key: const Key('repClaim.done'),
              label: l10n.repClaimDone,
              onPressed: () => context.go('/representatives/$repId'),
            ),
          ],
        ),
      ),
    );
  }
}
