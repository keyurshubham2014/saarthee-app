import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/staff_motion_scope.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/ensure_signed_in.dart';
import 'staff_session.dart';

/// `/staff/login`: phone sign-in (the app's Firebase flow, returning to
/// `/staff`) or the v1 admin email/password form.
class StaffLoginScreen extends ConsumerStatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  ConsumerState<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends ConsumerState<StaffLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showEmail = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(staffEmailSessionProvider.notifier)
          .signIn(_email.text, _password.text);
      ref.invalidate(staffMeProvider);
      if (mounted) context.go('/staff');
    } on AppError catch (e) {
      setState(
        () => _error = switch (e.code) {
          'INVALID_CREDENTIALS' || 'VALIDATION_FAILED' => l10n.staffLoginFailed,
          'ADMIN_DISABLED' => l10n.staffLoginSuspended,
          _ => l10n.staffLoadError,
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return StaffMotionScope(
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.staffConsoleTitle, style: text.titleMedium),
                  const SizedBox(height: AppSpacing.s8),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.staffLoginTitle,
                      style: text.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  PrimaryButton(
                    key: const Key('staff.login.phone'),
                    label: l10n.staffLoginPhone,
                    icon: SaartheeIcons.phone,
                    onPressed: () async {
                      final ok = await context.push<bool>(
                        signInLocation(from: '/staff'),
                      );
                      ref.invalidate(staffMeProvider);
                      if (ok == true && context.mounted) context.go('/staff');
                    },
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  if (!_showEmail)
                    TertiaryButton(
                      key: const Key('staff.login.emailLink'),
                      label: l10n.staffLoginEmailLink,
                      onPressed: () => setState(() => _showEmail = true),
                    )
                  else ...[
                    TextField(
                      key: const Key('staff.login.email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: l10n.staffLoginEmail,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    TextField(
                      key: const Key('staff.login.password'),
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: l10n.staffLoginPassword,
                      ),
                      onSubmitted: (_) => _signIn(),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    SecondaryButton(
                      key: const Key('staff.login.submit'),
                      label: l10n.staffLoginSubmit,
                      isLoading: _busy,
                      onPressed: _signIn,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.s12),
                    InlineFieldError(
                      key: const Key('staff.login.error'),
                      message: _error!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
