import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/motion_widgets.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';

/// `/onboarding/language` (REQ-F-004): both titles in their own scripts,
/// two 72 dp tiles, device-locale tile pre-highlighted. Tapping a tile
/// switches the locale at once; the chosen tile springs to 1.02 and back
/// with a selection haptic.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final current = ref.watch(localeProvider).languageCode;
    void choose(String code) {
      ref.read(saartheeHapticsProvider).selection();
      ref.read(localeProvider.notifier).setLanguage(code);
    }

    return Scaffold(
      body: PinnedBottomLayout(
        bottom: [
          PrimaryButton(
            key: const Key('onboarding.language.continue'),
            label: l10n.commonContinue,
            pinned: true,
            onPressed: () async {
              await ref.read(localeProvider.notifier).setLanguage(current);
              if (context.mounted) context.push('/onboarding/intro');
            },
          ),
        ],
        children: [
          const SizedBox(height: AppSpacing.s24),
          const Center(child: BrandMark(size: 56)),
          const SizedBox(height: AppSpacing.s24),
          Semantics(
            header: true,
            child: Column(
              children: [
                Text(
                  l10n.onboardingLanguageTitleGu,
                  style: text.headlineSmall,
                  textAlign: TextAlign.center,
                  locale: const Locale('gu'),
                ),
                Text(
                  l10n.onboardingLanguageTitleEn,
                  style: text.headlineSmall,
                  textAlign: TextAlign.center,
                  locale: const Locale('en'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s32),
          LanguageTile(
            key: const Key('onboarding.language.gu'),
            label: l10n.languageNameGu,
            locale: const Locale('gu'),
            selected: current == 'gu',
            onTap: () => choose('gu'),
          ),
          const SizedBox(height: AppSpacing.s12),
          LanguageTile(
            key: const Key('onboarding.language.en'),
            label: l10n.languageNameEn,
            locale: const Locale('en'),
            selected: current == 'en',
            onTap: () => choose('en'),
          ),
        ],
      ),
    );
  }
}

/// 72 dp language tile (radius 18): selected = `primaryContainer` fill and
/// 2 px `primary` outline; springs to 1.02 and back when it becomes
/// selected (`springIn`).
class LanguageTile extends StatefulWidget {
  const LanguageTile({
    super.key,
    required this.label,
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Locale locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<LanguageTile> createState() => LanguageTileState();
}

class LanguageTileState extends State<LanguageTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  /// Current spring scale (tests).
  double get scale {
    final t = _c.value;
    // Up to the peak over the first half, back over the second.
    final up = t < 0.5 ? t * 2 : (1 - t) * 2;
    return 1 + (SaartheeMotion.selectSpringScale - 1) * up;
  }

  @override
  void didUpdateWidget(LanguageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected) {
      final scheme = SaartheeMotion.of(context);
      if (!scheme.transforms) return;
      _c.duration = scheme.springIn.duration;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) =>
            Transform.scale(scale: scale, child: child),
        child: Material(
          color: widget.selected ? c.primaryContainer : c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.cardRadius,
            side: BorderSide(
              color: widget.selected ? c.primary : c.border,
              width: widget.selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: AppRadii.cardRadius,
            onTap: widget.onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        locale: widget.locale,
                        style: text.titleLarge,
                      ),
                    ),
                    Icon(
                      widget.selected
                          ? SaartheeIcons.radioOn
                          : SaartheeIcons.radioOff,
                      color: widget.selected ? c.primary : c.borderStrong,
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
