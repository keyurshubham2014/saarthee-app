import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/transitions.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/relay_consent.dart';
import '../application/ward_providers.dart';
import '../data/ward_api.dart';

const int kRelayBodyMax = 1000;

/// `/representatives/:id/message` (TASK-09 §5.4, REQ-F-044). Sign-in is
/// required by the route. The phone opt-in starts unticked. The form keeps
/// its text and `clientMessageId` on every error so a retry never sends
/// twice. On success the page closes and a "Message sent" toast with a
/// drawn check slides up over the profile (DS §6).
class MessageScreen extends ConsumerStatefulWidget {
  const MessageScreen({super.key, required this.repId, this.issueId});

  final String repId;
  final String? issueId;

  @override
  ConsumerState<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends ConsumerState<MessageScreen> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  late String _clientMessageId = newClientMessageId();
  late String? _issueId = widget.issueId;
  bool _sharePhone = false;
  bool _sending = false;
  bool _showFieldErrors = false;
  RelayFailure? _failure;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _subjectOk => _subject.text.trim().length >= 3;
  bool get _bodyOk => _body.text.trim().length >= 10;

  Future<bool> _askConsent() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showSaartheeSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        key: const Key('relay.consentSheet'),
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.relayConsentTitle,
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              l10n.relayConsentBody,
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s24),
            PrimaryButton(
              key: const Key('relay.consentAgree'),
              label: l10n.relayConsentAgree,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: AppSpacing.s8),
            TertiaryButton(
              label: l10n.relayConsentCancel,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return false;
    await ref.read(relayConsentProvider).grant();
    return true;
  }

  Future<void> _send(String repName) async {
    setState(() {
      _showFieldErrors = true;
      _failure = null;
    });
    if (!_subjectOk || !_bodyOk) return;
    final consent = ref.read(relayConsentProvider);
    if (!consent.granted && !await _askConsent()) return;
    if (!mounted) return;
    setState(() => _sending = true);
    final draft = RelayDraft(
      clientMessageId: _clientMessageId,
      subject: _subject.text,
      body: _body.text,
      sharePhone: _sharePhone,
      issueId: _issueId,
    );
    try {
      await ref.read(wardApiProvider).sendMessage(widget.repId, draft);
    } catch (e) {
      final failure = relayFailureOf(e);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failure = failure;
      });
      if (failure == RelayFailure.consent && await _askConsent() && mounted) {
        await _send(repName);
      }
      return;
    }
    if (!mounted) return;
    _clientMessageId = newClientMessageId();
    final l10n = AppLocalizations.of(context);
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    if (context.canPop()) context.pop(true);
    if (rootContext.mounted) {
      showSaartheeToast(rootContext, l10n.relaySent(repName));
    }
  }

  String? _failureText(AppLocalizations l10n) => switch (_failure) {
    null || RelayFailure.consent => null,
    RelayFailure.rateRep => l10n.relayErrorRateRep,
    RelayFailure.rateDaily => l10n.relayErrorRateDaily,
    RelayFailure.language => l10n.relayErrorLanguage,
    RelayFailure.noContact => l10n.repNoEmail,
    RelayFailure.offline => l10n.relayErrorOffline,
    RelayFailure.invalid || RelayFailure.other => l10n.relayErrorGeneric,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    final rep = ref.watch(repDetailProvider(widget.repId)).value;
    final name = rep?.summary.name(lang) ?? '';
    final failure = _failureText(l10n);
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.relayTitle(name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          if (failure != null) ...[
            Semantics(
              liveRegion: true,
              child: InlineFieldError(
                key: const Key('relay.error'),
                message: failure,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],
          if (_issueId != null)
            ListRow(
              key: const Key('relay.issue'),
              title: l10n.relayIssueAttached,
              subtitle: l10n.relayIssueLabel,
              trailing: TertiaryButton(
                label: l10n.relayIssueRemove,
                onPressed: () => setState(() => _issueId = null),
              ),
            ),
          LabeledTextField(
            fieldKey: const Key('relay.subject'),
            label: l10n.relaySubject,
            controller: _subject,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            error: _showFieldErrors && !_subjectOk
                ? l10n.relaySubjectShort
                : null,
          ),
          const SizedBox(height: AppSpacing.s16),
          LabeledTextField(
            fieldKey: const Key('relay.body'),
            label: l10n.relayMessage,
            controller: _body,
            maxLines: 6,
            inputFormatters: [LengthLimitingTextInputFormatter(kRelayBodyMax)],
            onChanged: (_) => setState(() {}),
            helper: l10n.relayCounter(_body.text.length),
            error: _showFieldErrors && !_bodyOk ? l10n.relayBodyShort : null,
          ),
          const SizedBox(height: AppSpacing.s8),
          CheckboxListTile(
            key: const Key('relay.sharePhone'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _sharePhone,
            onChanged: (v) => setState(() => _sharePhone = v ?? false),
            title: Text(l10n.relaySharePhone(name), style: text.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(l10n.relayNote(name), style: text.bodySmall),
          const SizedBox(height: AppSpacing.s8),
          Text(l10n.relayKindness, style: text.bodySmall),
          const SizedBox(height: AppSpacing.s24),
          PrimaryButton(
            key: const Key('relay.send'),
            label: l10n.relaySend,
            isLoading: _sending,
            onPressed: _sending || rep == null ? null : () => _send(name),
          ),
        ],
      ),
    );
  }
}
