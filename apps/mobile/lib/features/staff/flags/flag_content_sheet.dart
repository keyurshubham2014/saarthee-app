import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/ensure_signed_in.dart';
import '../shared/staff_labels.dart';

/// Outcome of a flag: sent, already reported, daily limit, or failure.
enum FlagOutcome { sent, already, limit, failed }

/// `POST /issues/{id}/flags` (TASK-10 §5.3).
Future<FlagOutcome> sendFlag(WidgetRef ref, String issueId, {required String reason, String? note, String? eventId}) async {
  try {
    final j = await ref.read(apiClientProvider).postJson('/issues/$issueId/flags', body: {
      'reason': reason,
      if (note != null && note.isNotEmpty) 'note': note,
      'eventId': ?eventId,
    });
    return j['alreadyReported'] == true ? FlagOutcome.already : FlagOutcome.sent;
  } on AppError catch (e) {
    return e.code == 'FLAG_QUOTA' || e.code == 'RATE_LIMITED' ? FlagOutcome.limit : FlagOutcome.failed;
  }
}

/// "Report a problem with this post" (REQ-F-051) for an issue or, with
/// [eventId], one of its comments. Signed-out people sign in first and
/// return here. TASK-07 places the entry point on issue detail.
Future<void> showFlagContentSheet(BuildContext context, WidgetRef ref, {required String issueId, String? eventId}) async {
  if (!await ensureSignedIn(context, ref, reason: SignInReason.generic)) return;
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final outcome = await showModalBottomSheet<FlagOutcome>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))),
    builder: (_) => FlagContentSheet(issueId: issueId, eventId: eventId),
  );
  if (outcome == null || !context.mounted) return;
  showSaartheeToast(
    context,
    switch (outcome) {
      FlagOutcome.sent => l10n.flagThanks,
      FlagOutcome.already => l10n.flagAlready,
      FlagOutcome.limit => l10n.flagLimit,
      FlagOutcome.failed => l10n.flagError,
    },
    kind: outcome == FlagOutcome.failed || outcome == FlagOutcome.limit ? ToastKind.error : ToastKind.success,
  );
}

class FlagContentSheet extends ConsumerStatefulWidget {
  const FlagContentSheet({super.key, required this.issueId, this.eventId});

  final String issueId;
  final String? eventId;

  @override
  ConsumerState<FlagContentSheet> createState() => _FlagContentSheetState();
}

class _FlagContentSheetState extends ConsumerState<FlagContentSheet> {
  String? _reason;
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final outcome = await sendFlag(ref, widget.issueId, reason: _reason!, note: _note.text.trim(), eventId: widget.eventId);
    if (mounted) Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            key: const Key('flag.sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(header: true, child: Text(l10n.flagSheetTitle, style: text.titleLarge)),
              const SizedBox(height: AppSpacing.s12),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(children: [
                  for (final r in flagReasons)
                    RadioListTile<String>(key: Key('flag.reason.$r'), value: r, title: Text(flagReasonLabel(l10n, r))),
                ]),
              ),
              TextField(
                key: const Key('flag.note'),
                controller: _note,
                maxLength: 200,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(labelText: l10n.flagNote, counterText: l10n.flagCounter(_note.text.length)),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.s12),
              PrimaryButton(
                key: const Key('flag.send'),
                label: l10n.flagSend,
                isLoading: _sending,
                onPressed: _reason == null ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
