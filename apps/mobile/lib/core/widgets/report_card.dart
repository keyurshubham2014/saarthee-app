import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../motion/haptics.dart';
import '../motion/pressable.dart';
import '../motion/rise_in.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';

/// The `sunrise` Report card (DS §5): ≥ 56 dp, radius 14, white filled "+"
/// in a 32 dp circle, title + one-line hint, trailing arrow, `sunrise`
/// glow. Springs in. The only `sunrise` element on its screen.
class ReportCard extends ConsumerStatefulWidget {
  const ReportCard({super.key, required this.onPressed, this.animate = true});

  final VoidCallback onPressed;
  final bool animate;

  @override
  ConsumerState<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<ReportCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final fg = c.onSunrise;
    return RiseIn(
      animate: widget.animate,
      child: Semantics(
        button: true,
        label: '${l10n.homeReportCardTitle}. ${l10n.homeReportCardHint}',
        excludeSemantics: true,
        child: Pressable(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadii.controlRadius,
              boxShadow: AppElevation.reportGlow(c),
            ),
            child: Material(
              key: const Key('reportCard'),
              color: _pressed ? c.sunrisePressed : c.sunrise,
              borderRadius: AppRadii.controlRadius,
              child: InkWell(
                borderRadius: AppRadii.controlRadius,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                onTap: () {
                  ref.read(saartheeHapticsProvider).light();
                  widget.onPressed();
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.reportCardMinHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s14,
                      vertical: AppSpacing.s12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: fg.withValues(alpha: 0.2),
                          ),
                          child: Icon(
                            SaartheeIcons.add,
                            fill: SaartheeIcons.fillOn,
                            color: fg,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.homeReportCardTitle,
                                style: text.titleMedium?.copyWith(color: fg),
                              ),
                              Text(
                                l10n.homeReportCardHint,
                                style: text.bodySmall?.copyWith(color: fg),
                              ),
                            ],
                          ),
                        ),
                        Icon(SaartheeIcons.forward, color: fg),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
