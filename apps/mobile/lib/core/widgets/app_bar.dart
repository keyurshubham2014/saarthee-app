import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../settings/locale_controller.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';

/// "અ" / "A" language toggle. In English it offers Gujarati ("અ", label
/// "ગુજરાતીમાં બદલો"); in Gujarati it offers English ("A", "Switch to
/// English"). [onDark] draws the 36 dp white-14% circle used on the green
/// header. Always a 48 dp target.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final gu = ref.watch(localeProvider).languageCode == 'gu';
    final glyph = gu ? l10n.languageGlyphEn : l10n.languageGlyphGu;
    final label = gu
        ? l10n.languageSwitchToEnglish
        : l10n.languageSwitchToGujarati;
    return HeaderCircleButton(
      key: const Key('languageToggle'),
      tooltip: label,
      onDark: onDark,
      onPressed: () => ref.read(localeProvider.notifier).toggle(),
      child: Text(
        glyph,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: onDark
              ? NeemFixed.white
              : SaartheeColors.of(context).textPrimary,
        ),
      ),
    );
  }
}

/// 36 dp circle button inside a 48 dp target (Home header, app bar).
class HeaderCircleButton extends StatelessWidget {
  const HeaderCircleButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.onDark = false,
    this.badge,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool onDark;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox.square(
          dimension: AppSpacing.touchTarget,
          child: Material(
            type: MaterialType.transparency,
            child: InkResponse(
              onTap: onPressed,
              radius: AppSpacing.touchTarget / 2,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: AppSpacing.headerButton,
                      height: AppSpacing.headerButton,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: onDark ? NeemFixed.headerButton : c.surfaceAlt,
                      ),
                      child: ExcludeSemantics(child: child),
                    ),
                    if (badge != null)
                      Positioned(right: -2, top: -2, child: badge!),
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

/// App bar for every non-Home screen (DS §5): white surface, left-aligned
/// headlineSmall title, optional subtitle (ward), back arrow, language
/// toggle, optional bell slot; 1 px bottom border once content scrolls.
class SaartheeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SaartheeAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.onBack,
    this.actions = const [],
    this.showLanguageToggle = true,
    this.bell,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool showLanguageToggle;
  final Widget? bell;

  @override
  Size get preferredSize =>
      Size.fromHeight(subtitle == null ? kToolbarHeight : kToolbarHeight + 16);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final theme = Theme.of(context);
    final canPop = onBack != null || Navigator.of(context).canPop();
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: preferredSize.height,
      leading: showBack && canPop
          ? IconButton(
              tooltip: l10n.commonBack,
              icon: const Icon(SaartheeIcons.back),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      titleSpacing: showBack && canPop ? 0 : AppSpacing.gutter,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.headlineSmall,
              // One line: the toolbar is kToolbarHeight tall, so a second line
              // overflowed into the status bar on long titles (detail screens
              // repeat the full title in their body; TalkBack reads it whole).
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [
        ...actions,
        if (showLanguageToggle) const LanguageToggle(),
        ?bell,
        const SizedBox(width: AppSpacing.s8),
      ],
      shape: Border(bottom: BorderSide(color: c.border)),
      // The border shows only once content scrolls under the bar.
      notificationPredicate: (n) => n.depth == 0,
      scrolledUnderElevation: 0,
    );
  }
}
