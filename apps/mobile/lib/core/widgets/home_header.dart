import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import 'app_bar.dart';
import 'report_card.dart';

/// The green Home header band (DS §4–§5): ward line (`onPrimarySubtle`),
/// greeting (displaySmall, white), language + bell as 36 dp circles inside
/// 48 dp targets, and the `sunrise` [ReportCard] overlapping the page.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.wardLabel,
    required this.onWardTap,
    required this.onReport,
    required this.onBell,
    this.animateReportCard = true,
  });

  /// "Ward 12 · Paldi", or null when no home ward is set ("Set your ward").
  final String? wardLabel;
  final VoidCallback onWardTap;
  final VoidCallback onReport;
  final VoidCallback onBell;
  final bool animateReportCard;

  /// How far the Report card hangs below the band (half its min height).
  static const double overlap = AppSpacing.reportCardMinHeight / 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    // Dark theme: the band is the deep brand green with light text.
    final band = c.isDark ? c.primaryDark : c.primary;
    final onBand = c.isDark ? c.textPrimary : NeemFixed.white;
    final subtle = c.isDark ? c.onPrimaryContainer : c.onPrimarySubtle;
    return Stack(
      children: [
        // The band stops halfway down the Report card, so the card overlaps
        // the page like a hero (DS §4).
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: overlap,
          child: ColoredBox(key: const Key('homeHeader.band'), color: band),
        ),
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + AppSpacing.s8,
            left: AppSpacing.gutter,
            right: AppSpacing.gutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          button: true,
                          label: wardLabel ?? l10n.homeSetYourWard,
                          excludeSemantics: true,
                          child: InkWell(
                            key: const Key('homeHeader.ward'),
                            onTap: onWardTap,
                            borderRadius: AppRadii.controlRadius,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: AppSpacing.touchTarget,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    SaartheeIcons.location,
                                    size: AppSpacing.iconSmall,
                                    color: subtle,
                                  ),
                                  const SizedBox(width: AppSpacing.s4),
                                  Flexible(
                                    child: Text(
                                      wardLabel ?? l10n.homeSetYourWard,
                                      style: text.bodyMedium?.copyWith(
                                        color: subtle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.homeGreeting,
                            style: text.displaySmall?.copyWith(color: onBand),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const LanguageToggle(onDark: true),
                  HeaderCircleButton(
                    key: const Key('homeHeader.bell'),
                    tooltip: l10n.commonNotifications,
                    onDark: true,
                    onPressed: onBell,
                    child: Icon(SaartheeIcons.notifications, color: onBand),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),
              ReportCard(onPressed: onReport, animate: animateReportCard),
            ],
          ),
        ),
      ],
    );
  }
}
