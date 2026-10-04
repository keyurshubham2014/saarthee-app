import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../application/ensure_signed_in.dart';
import '../application/phone_sign_in.dart';

/// `/sign-in?from=&reason=` (TASK-04 §5.4): fixed +91 prefix, 10-digit
/// number, "Send code" with in-button progress; offline disables the button.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    super.key,
    this.from,
    this.reason = SignInReason.generic,
  });

  final String? from;
  final SignInReason reason;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _phone = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final digits = Validators.normalizePhone(_phone.text);
    if (digits == null) {
      setState(() => _error = l10n.authPhoneInvalid);
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      await ref.read(phoneSignInProvider.notifier).sendCode(digits);
      if (!mounted) return;
      setState(() => _sending = false);
      final ok = await context.push<bool>('/sign-in/otp');
      if (!mounted || ok == null) return;
      finishSignIn(context, ok, from: widget.from);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = authErrorText(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final offline = ref.watch(isOfflineProvider);
    return Scaffold(
      appBar: SaartheeAppBar(
        title: l10n.authSignInTitle,
        onBack: () => finishSignIn(context, false),
      ),
      body: PinnedBottomLayout(
        top: offline ? const NoticeBanner(kind: NoticeKind.offline) : null,
        bottom: [
          PrimaryButton(
            key: const Key('signIn.send'),
            label: l10n.authSendCode,
            isLoading: _sending,
            pinned: true,
            onPressed: offline ? null : _send,
          ),
        ],
        children: [
          Text(
            widget.reason.text(l10n),
            key: const Key('signIn.reason'),
            style: text.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.s24),
          LabeledTextField(
            fieldKey: const Key('signIn.phone'),
            label: l10n.authPhoneLabel,
            controller: _phone,
            prefixText: '+91',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            helper: l10n.authPhoneHelper,
            error: _error,
            onSubmitted: (_) => offline ? null : _send(),
          ),
        ],
      ),
    );
  }
}
