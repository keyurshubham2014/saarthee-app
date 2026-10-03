import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'offline_banner.dart';
import 'page_layout.dart';

/// "One decision per screen" step layout (02 §2.0, §3.3): Back, "Step n of N"
/// (announced), display question, body, and primary action(s) pinned at the
/// bottom above the keyboard.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
    this.step,
    this.total,
    this.onBack,
    this.showOfflineBanner = false,
    this.onRetryOffline,
  });

  final int? step;
  final int? total;
  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showOfflineBanner;
  final VoidCallback? onRetryOffline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canPop = onBack != null || Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                tooltip: l10n.commonBack,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            : null,
        title: step != null && total != null
            ? Semantics(
                liveRegion: true,
                child: Text(
                  l10n.commonStepOf(step!, total!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              )
            : null,
      ),
      body: PinnedBottomLayout(
        top: showOfflineBanner ? OfflineBanner(onRetry: onRetryOffline) : null,
        bottom: actions,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.headlineMedium),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...children,
        ],
      ),
    );
  }
}
