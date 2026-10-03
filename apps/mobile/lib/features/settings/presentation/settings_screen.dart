import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/settings/motion_preference.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/theme_mode.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../onboarding/presentation/ward_picker_sheet.dart';

/// `/me/settings`: language, appearance, Animations, home ward, About.
/// Every change applies instantly.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    final mode = ref.watch(themeModeProvider);
    final animations = ref.watch(motionPreferenceProvider);
    final systemOff = ref.watch(systemDisableAnimationsProvider);
    final ward = ref.watch(homeWardProvider);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sectionTitleTop,
        AppSpacing.gutter,
        AppSpacing.s8,
      ),
      child: Semantics(header: true, child: Text(title, style: text.titleLarge)),
    );

    Widget radio<T>({
      required Key key,
      required String label,
      required T value,
      required T group,
      required ValueChanged<T> onChanged,
      Locale? locale,
    }) {
      final selected = value == group;
      return Semantics(
        key: key,
        inMutuallyExclusiveGroup: true,
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onChanged(value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Row(
                children: [
                  Icon(
                    selected ? SaartheeIcons.radioOn : SaartheeIcons.radioOff,
                    color: selected ? c.primary : c.borderStrong,
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Text(label, style: text.bodyLarge, locale: locale),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.settingsTitle),
      body: ListView(
        key: const PageStorageKey('settings.scroll'),
        children: [
          section(l10n.settingsLanguage),
          radio<String>(
            key: const Key('settings.lang.gu'),
            label: l10n.languageNameGu,
            locale: const Locale('gu'),
            value: 'gu',
            group: lang,
            onChanged: (v) => ref.read(localeProvider.notifier).setLanguage(v),
          ),
          radio<String>(
            key: const Key('settings.lang.en'),
            label: l10n.languageNameEn,
            locale: const Locale('en'),
            value: 'en',
            group: lang,
            onChanged: (v) => ref.read(localeProvider.notifier).setLanguage(v),
          ),
          section(l10n.settingsAppearance),
          for (final (m, label) in [
            (ThemeMode.system, l10n.settingsThemeSystem),
            (ThemeMode.light, l10n.settingsThemeLight),
            (ThemeMode.dark, l10n.settingsThemeDark),
          ])
            radio<ThemeMode>(
              key: Key('settings.theme.${m.name}'),
              label: label,
              value: m,
              group: mode,
              onChanged: (v) => ref.read(themeModeProvider.notifier).set(v),
            ),
          section(l10n.settingsAnimations),
          SwitchListTile(
            key: const Key('settings.animations'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
            ),
            title: Text(l10n.settingsAnimations, style: text.bodyLarge),
            subtitle: Text(
              systemOff
                  ? l10n.settingsAnimationsSystemOff
                  : l10n.settingsAnimationsHelper,
              style: text.bodySmall,
            ),
            value: systemOff ? false : animations,
            onChanged: systemOff
                ? null
                : (v) => ref.read(motionPreferenceProvider.notifier).setEnabled(v),
          ),
          section(l10n.settingsHomeWard),
          ListRow(
            key: const Key('settings.homeWard'),
            leading: Icon(SaartheeIcons.navMyWard, color: c.textSecondary),
            title: ward == null
                ? l10n.settingsHomeWardNone
                : l10n.wardDisplayName(ward.number, ward.name(lang)),
            trailing: Text(
              l10n.commonChange,
              style: text.labelLarge?.copyWith(color: c.primary),
            ),
            onTap: () async {
              final picked = await showWardPicker(context);
              if (picked != null) {
                await ref.read(homeWardProvider.notifier).set(picked);
              }
            },
          ),
          const SizedBox(height: AppSpacing.s16),
          const Divider(),
          ListRow(
            key: const Key('settings.about'),
            leading: Icon(SaartheeIcons.info, color: c.textSecondary),
            title: l10n.aboutTitle,
            onTap: () => context.push('/about'),
          ),
          const SizedBox(height: AppSpacing.s24),
        ],
      ),
    );
  }
}
