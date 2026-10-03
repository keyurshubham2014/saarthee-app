import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_l10n.dart';
import '../../application/admin_auth.dart';
import '../admin_format.dart';
import '../admin_paths.dart';
import '../widgets/admin_widgets.dart';

/// `/admin/login` (02 §4.17).
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key, this.from});

  /// Route to return to after login (validated admin path).
  final String? from;

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  late final bool _showSessionEnded;

  @override
  void initState() {
    super.initState();
    _showSessionEnded = ref.read(adminAuthProvider).sessionEnded;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final ok = await ref
        .read(adminLoginProvider.notifier)
        .submit(email: _email.text, password: _password.text);
    if (!ok || !mounted) {
      return;
    }
    ref.read(adminAuthProvider.notifier).acknowledgeSessionEnded();
    context.go(safeAdminReturnPath(widget.from));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    final login = ref.watch(adminLoginProvider);
    final error = login.error;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminLoginTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: adminScreenPadding,
          child: AdminContentWidth(
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_showSessionEnded && error == null) ...<Widget>[
                      AdminMessageBanner(
                        message: l10n.adminSessionEnded,
                        icon: Icons.lock_clock_rounded,
                        isError: false,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (error != null) ...<Widget>[
                      AdminMessageBanner(
                        message: adminErrorMessage(l10n, error),
                        icon: error.isNetwork
                            ? Icons.cloud_off_rounded
                            : Icons.error_rounded,
                        onRetry: error.isNetwork && !login.submitting
                            ? _submit
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      l10n.adminLoginIntro,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('adminLoginEmail'),
                      controller: _email,
                      enabled: !login.submitting,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const <String>[AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.adminLoginEmailLabel,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return l10n.adminLoginEmailRequired;
                        }
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(text)) {
                          return l10n.adminLoginEmailInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('adminLoginPassword'),
                      controller: _password,
                      enabled: !login.submitting,
                      obscureText: _obscure,
                      autofillHints: const <String>[AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.adminLoginPasswordLabel,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          tooltip: _obscure
                              ? l10n.adminLoginShowPassword
                              : l10n.adminLoginHidePassword,
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) => (value ?? '').isEmpty
                          ? l10n.adminLoginPasswordRequired
                          : null,
                    ),
                    const SizedBox(height: 32),
                    AdminPrimaryButton(
                      key: const Key('adminLoginSubmit'),
                      label: l10n.adminLoginSubmit,
                      busy: login.submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
