import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/timings.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../application/phone_sign_in.dart';
import '../application/session_controller.dart';
import 'signed_in_check.dart';

/// `/sign-in/otp` (TASK-04 §5.4): 6-digit code (SMS autofill), "Resend code"
/// after a 30 s countdown, "Change number". On success the drawn check and
/// "Signed in" show before the route pops back with `true`.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _wait = AppTimings.otpResendWait.inSeconds;
  bool _verifying = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _wait = AppTimings.otpResendWait.inSeconds);
    _timer = Timer.periodic(AppTimings.countdownTick, (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait -= 1);
      if (_wait <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(phoneSignInProvider.notifier).resend();
      if (mounted) setState(() => _error = null);
      _startCountdown();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(l10n, e));
    }
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      setState(() => _error = l10n.authOtpWrong);
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final outcome = await ref
          .read(phoneSignInProvider.notifier)
          .verify(_code.text);
      if (!mounted) return;
      if (outcome == ExchangeOutcome.needsAge) {
        setState(() => _verifying = false);
        final ok = await context.push<bool>('/sign-in/age');
        if (mounted && ok != null) context.pop(ok);
        return;
      }
      setState(() => _done = true);
      await Future<void>.delayed(signedInCheckWait(context));
      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = authErrorText(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final phone = ref.watch(phoneSignInProvider).phoneE164 ?? '';
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.authOtpTitle),
      body: PinnedBottomLayout(
        bottom: [
          if (_done)
            const SignedInCheck()
          else
            PrimaryButton(
              key: const Key('otp.verify'),
              label: l10n.authOtpVerify,
              isLoading: _verifying,
              pinned: true,
              onPressed: _verify,
            ),
        ],
        children: [
          Text(
            l10n.authOtpSentTo(Formatters.phone(phone)),
            style: text.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.s24),
          LabeledTextField(
            fieldKey: const Key('otp.code'),
            label: l10n.authOtpLabel,
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            enabled: !_done,
            error: _error,
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: AppSpacing.s16),
          TertiaryButton(
            key: const Key('otp.resend'),
            label: _wait > 0 ? l10n.authOtpResendIn(_wait) : l10n.authOtpResend,
            onPressed: _wait > 0 || _done ? null : _resend,
          ),
          TertiaryButton(
            key: const Key('otp.changeNumber'),
            label: l10n.authOtpChangeNumber,
            onPressed: _done ? null : () => context.pop(),
          ),
        ],
      ),
    );
  }
}
