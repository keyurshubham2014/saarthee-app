import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/transitions.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/phone_sign_in.dart';
import 'signed_in_check.dart';

/// `/sign-in/age` — new accounts only (REQ-S-005): "Are you 18 or older?",
/// core consent box with the privacy notice, "Create account" enabled only
/// when "Yes" is chosen and the box is ticked. "No" → `/sign-in/blocked`,
/// Firebase signed out, nothing stored.
class AgeScreen extends ConsumerStatefulWidget {
  const AgeScreen({super.key});

  @override
  ConsumerState<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends ConsumerState<AgeScreen> {
  bool _adult = false;
  bool _consent = false;
  bool _creating = false;
  bool _done = false;
  String? _error;

  Future<void> _no() async {
    await ref.read(phoneSignInProvider.notifier).declineAge();
    if (!mounted) return;
    await context.push<void>('/sign-in/blocked');
    if (mounted) context.pop(false);
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await ref.read(phoneSignInProvider.notifier).confirmAge();
      if (!mounted) return;
      setState(() => _done = true);
      await Future<void>.delayed(signedInCheckWait(context));
      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = authErrorText(l10n, e);
      });
    }
  }

  void _showNotice() {
    final l10n = AppLocalizations.of(context);
    showSaartheeSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.authPrivacyNotice,
                style: Theme.of(c).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                l10n.authPrivacyNoticeBody,
                style: Theme.of(c).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.authAgeTitle),
      body: PinnedBottomLayout(
        bottom: [
          if (_error != null) InlineFieldError(message: _error!),
          if (_done)
            const SignedInCheck()
          else
            PrimaryButton(
              key: const Key('age.create'),
              label: l10n.authCreateAccount,
              isLoading: _creating,
              pinned: true,
              onPressed: _adult && _consent ? _create : null,
            ),
        ],
        children: [
          Semantics(
            header: true,
            child: Text(l10n.authAgeTitle, style: text.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(l10n.authAgeBody, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.s16),
          Semantics(
            selected: _adult,
            child: SecondaryButton(
              key: const Key('age.yes'),
              label: l10n.authAgeYes,
              icon: _adult ? SaartheeIcons.check : null,
              onPressed: () => setState(() => _adult = true),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          SecondaryButton(
            key: const Key('age.no'),
            label: l10n.authAgeNo,
            onPressed: _creating || _done ? null : _no,
          ),
          const SizedBox(height: AppSpacing.s24),
          CheckboxListTile(
            key: const Key('age.consent'),
            value: _consent,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n.authConsentCore, style: text.bodyLarge),
            onChanged: (v) => setState(() => _consent = v ?? false),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TertiaryButton(
              key: const Key('age.privacyNotice'),
              label: l10n.authPrivacyNotice,
              onPressed: _showNotice,
            ),
          ),
        ],
      ),
    );
  }
}
