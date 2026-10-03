import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward.dart';
import '../../../core/widgets/widgets.dart';
import '../application/ward_step_controller.dart';
import 'ward_picker_sheet.dart';

/// `/onboarding/ward`: home ward by GPS or picker, or skip. Every failure
/// (location off, outside the city, API down) keeps a way forward.
class WardScreen extends ConsumerWidget {
  const WardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    final s = ref.watch(wardStepControllerProvider);
    final ctl = ref.read(wardStepControllerProvider.notifier);

    Future<void> finish(Ward? ward) async {
      await ctl.finish(ward);
      if (context.mounted) context.go('/');
    }

    Future<void> pick() async {
      final ward = await showWardPicker(context);
      if (ward != null) await finish(ward);
    }

    Widget message(String body, {IconData icon = SaartheeIcons.info}) =>
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: c.isDark ? c.surfaceAlt : c.warningTint,
              borderRadius: AppRadii.cardRadius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: c.warning),
                const SizedBox(width: AppSpacing.s12),
                Expanded(child: Text(body, style: text.bodyLarge)),
              ],
            ),
          ),
        );

    final found = s.result;
    final List<Widget> body;
    final List<Widget> actions;
    switch (s.phase) {
      case WardStepPhase.found when found != null:
        final name = l10n.wardDisplayName(
          found.ward.number,
          found.ward.name(lang),
        );
        body = [
          Container(
            key: const Key('ward.result'),
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: AppElevation.cardDecoration(c),
            child: Row(
              children: [
                Icon(SaartheeIcons.location, color: c.primary),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    found.confirm
                        ? l10n.wardLocateConfirm(name)
                        : l10n.wardLocateResult(
                            name,
                            found.ward.zone.name(lang),
                          ),
                    style: text.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ];
        actions = [
          PrimaryButton(
            key: const Key('ward.yes'),
            label: l10n.wardYesContinue,
            pinned: true,
            onPressed: () => finish(found.ward),
          ),
          SecondaryButton(
            key: const Key('ward.chooseAnother'),
            label: l10n.wardChooseAnother,
            onPressed: pick,
          ),
        ];
      case WardStepPhase.locationOff:
        body = [
          message(l10n.wardLocationDenied, icon: SaartheeIcons.locationOff),
        ];
        actions = [
          SecondaryButton(
            key: const Key('ward.openSettings'),
            label: l10n.commonOpenSettings,
            icon: SaartheeIcons.settings,
            onPressed: ctl.openSettings,
          ),
          PrimaryButton(
            key: const Key('ward.choose'),
            label: l10n.wardChooseFromList,
            pinned: true,
            onPressed: pick,
          ),
          TertiaryButton(
            key: const Key('ward.skip'),
            label: l10n.wardSkip,
            onPressed: () => finish(null),
          ),
        ];
      case WardStepPhase.outsideCity:
        body = [message(l10n.wardOutsideCity)];
        actions = [
          PrimaryButton(
            key: const Key('ward.choose'),
            label: l10n.wardChooseFromList,
            pinned: true,
            onPressed: pick,
          ),
          TertiaryButton(
            key: const Key('ward.skip'),
            label: l10n.wardSkip,
            onPressed: () => finish(null),
          ),
        ];
      case WardStepPhase.unavailable:
        body = [message(l10n.wardApiDown, icon: SaartheeIcons.error)];
        actions = [
          PrimaryButton(
            key: const Key('ward.retry'),
            label: l10n.commonRetry,
            pinned: true,
            onPressed: ctl.useLocation,
          ),
          SecondaryButton(
            key: const Key('ward.choose'),
            label: l10n.wardChooseFromList,
            onPressed: pick,
          ),
          TertiaryButton(
            key: const Key('ward.skip'),
            label: l10n.wardSkip,
            onPressed: () => finish(null),
          ),
        ];
      default:
        final locating = s.phase == WardStepPhase.locating;
        body = [
          if (locating)
            Semantics(
              liveRegion: true,
              child: Text(l10n.wardLocating, style: text.bodyLarge),
            )
          else
            Text(l10n.wardLocationRationale, style: text.bodySmall),
        ];
        actions = [
          PrimaryButton(
            key: const Key('ward.useLocation'),
            label: l10n.wardUseLocation,
            icon: SaartheeIcons.myLocation,
            pinned: true,
            isLoading: locating,
            onPressed: ctl.useLocation,
          ),
          SecondaryButton(
            key: const Key('ward.choose'),
            label: l10n.wardChooseFromList,
            onPressed: locating ? null : pick,
          ),
          TertiaryButton(
            key: const Key('ward.skip'),
            label: l10n.wardSkip,
            onPressed: locating ? null : () => finish(null),
          ),
        ];
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          icon: const Icon(SaartheeIcons.back),
          onPressed: () => context.pop(),
        ),
      ),
      body: PinnedBottomLayout(
        bottom: actions,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.wardStepTitle, style: text.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(l10n.wardStepHelper, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.s24),
          ...body,
        ],
      ),
    );
  }
}
