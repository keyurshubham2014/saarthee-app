import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/session_controller.dart';

/// "You" row on My Ward (replaces placeholder P-09): signed out → "Sign in"
/// with why; signed in → name (or "Your account") and masked phone. Opens `/me`.
class MeRow extends ConsumerWidget {
  const MeRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final session = ref.watch(sessionProvider);
    final me = session.me;
    final title = !session.signedIn
        ? l10n.accountSignInRow
        : (me?.displayName?.isNotEmpty ?? false)
        ? me!.displayName!
        : l10n.accountTitle;
    final subtitle = !session.signedIn
        ? l10n.accountSignInWhy
        : me?.phoneMasked == null
        ? null
        : l10n.accountSignedInAs(me!.phoneMasked!);
    return ListRow(
      key: const Key('myWard.me'),
      leading: Icon(SaartheeIcons.person, color: c.primary),
      title: title,
      subtitle: subtitle,
      onTap: () => context.push('/me'),
    );
  }
}
