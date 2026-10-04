import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/seen_once.dart';
import '../../../core/motion/staggered.dart';
import '../../../core/motion/rise_in.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../alerts/application/alerts_providers.dart';
import '../../discovery/application/discovery_providers.dart';
import '../../discovery/presentation/home_feed_section.dart';
import '../../discovery/presentation/widgets/chevron_refresh_indicator.dart';
import '../../onboarding/presentation/ward_picker_sheet.dart';
import '../../me/presentation/push_prompt_card.dart';
import '../../services/presentation/home_services_section.dart';
import 'report_card_intro.dart';

/// Session key: the header + Report card intro plays once per app process.
const String homeHeaderIntroKey = 'home.header';

/// Home tab (branch 0, TASK-07): the green header band with the `sunrise`
/// Report card, then the ward's alerts, stats and issues near you (P-01/P-02
/// replaced), TASK-12's tip, drives and services. Branded pull to refresh.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const reportBranch = 2;
  static const alertsBranch = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ward = ref.watch(homeWardProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final shell = StatefulNavigationShell.maybeOf(context);
    void report() => shell?.goBranch(reportBranch);
    void alerts() => shell?.goBranch(alertsBranch);
    Future<void> pickWard() async {
      final picked = await showWardPicker(context);
      if (picked != null) {
        await ref.read(homeWardProvider.notifier).set(picked);
      }
    }

    Future<void> refresh() async {
      ref.invalidate(alertsListProvider(true));
      if (ward == null) return;
      ref.invalidate(homeFeedProvider(ward.id));
      await ref
          .read(homeFeedProvider(ward.id).future)
          .catchError((_) => const HomeFeed(nearby: []));
    }

    final c = SaartheeColors.of(context);
    return Scaffold(
      body: Stack(
        children: [
          ChevronRefreshIndicator(
            onRefresh: refresh,
            child: CustomScrollView(
              key: const PageStorageKey('home.scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SeenOnce(
                    seenKey: homeHeaderIntroKey,
                    builder: (context, animate) => RiseIn(
                      animate: animate,
                      child: HomeHeader(
                        wardLabel: ward == null
                            ? null
                            : l10n.wardDisplayName(
                                ward.number,
                                ward.name(lang),
                              ),
                        onWardTap: pickWard,
                        onReport: report,
                        onBell: alerts,
                        // The Report card springs (ReportCardIntro), not rises.
                        animateReportCard: false,
                        decorateReportCard: (card) => RiseIn(
                          animate: animate,
                          delay: staggerDelay(SaartheeMotion.of(context), 1),
                          child: ReportCardIntro(animate: animate, child: card),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList.list(
                  children: [
                    // TASK-04: push soft prompt (never at first launch).
                    const PushPromptCard(),
                    if (ward == null)
                      EmptyState(
                        key: const Key('home.chooseWard'),
                        icon: SaartheeIcons.location,
                        message: l10n.discoveryChooseWardPrompt,
                        actionLabel: l10n.discoveryChooseWard,
                        onAction: pickWard,
                      )
                    else
                      HomeFeedSection(
                        ward: ward,
                        onReport: report,
                        onAlerts: alerts,
                      ),
                    // TASK-12: tip, drives and service shortcuts (replaces P-03).
                    const HomeServicesSection(),
                    const SizedBox(height: AppSpacing.s40),
                  ],
                ),
              ],
            ),
          ),
          // Status-bar scrim in the header band colour: content scrolled up
          // never runs under the system clock and icons (a11y audit, 2.0×).
          Positioned(
            key: const Key('home.statusScrim'),
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: IgnorePointer(
              child: ColoredBox(color: c.isDark ? c.primaryDark : c.primary),
            ),
          ),
        ],
      ),
    );
  }
}
