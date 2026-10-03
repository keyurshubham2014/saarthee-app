import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/icons.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Five-tab citizen navigation (DS §5): M3 `NavigationBar` (its semantics
/// and 48 dp targets) with labels always visible, the filled Rounded icon on
/// the selected tab, and the Report glyph always filled in `sunrise`. The M3
/// indicator is transparent; an animated `primaryContainer` pill behind the
/// icons slides and stretches between tabs over `short` (DS §6).
class SaartheeNavigationBar extends StatelessWidget {
  const SaartheeNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const int reportIndex = 2;
  static const double pillWidth = 64;
  static const double pillHeight = 32;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final destinations = <(IconData, String)>[
      (SaartheeIcons.navHome, l10n.navHome),
      (SaartheeIcons.navMap, l10n.navMap),
      (SaartheeIcons.navReport, l10n.navReport),
      (SaartheeIcons.navAlerts, l10n.navAlerts),
      (SaartheeIcons.navMyWard, l10n.navMyWard),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: NavPill(
                  index: selectedIndex,
                  count: destinations.length,
                  color: c.primaryContainer,
                ),
              ),
            ),
          ),
          NavigationBar(
            backgroundColor: NeemFixed.transparent,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            animationDuration: SaartheeMotion.of(context).short.duration,
            destinations: [
              for (var i = 0; i < destinations.length; i++)
                NavigationDestination(
                  key: Key('nav.$i'),
                  icon: i == reportIndex
                      ? Icon(
                          destinations[i].$1,
                          fill: SaartheeIcons.fillOn,
                          color: c.sunrise,
                        )
                      : Icon(destinations[i].$1, fill: SaartheeIcons.fillOff),
                  selectedIcon: Icon(
                    destinations[i].$1,
                    fill: SaartheeIcons.fillOn,
                    color: i == reportIndex ? c.sunrise : c.onPrimaryContainer,
                  ),
                  label: destinations[i].$2,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The sliding, stretching pill. Transform only: the pill is a fixed-size
/// box translated to the selected slot and scaled horizontally mid-flight.
class NavPill extends StatefulWidget {
  const NavPill({
    super.key,
    required this.index,
    required this.count,
    required this.color,
  });

  final int index;
  final int count;
  final Color color;

  @override
  State<NavPill> createState() => NavPillState();
}

class NavPillState extends State<NavPill> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    value: 1,
  );
  late double _from = widget.index.toDouble();

  /// Current slot position (fractional while moving), for tests.
  double get position {
    final t = SaartheeMotion.standard.transform(_c.value);
    return _from + (widget.index - _from) * t;
  }

  @override
  void didUpdateWidget(NavPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _from = position;
      final spec = SaartheeMotion.of(context).short;
      if (spec.isInstant) {
        _c.value = 1;
        _from = widget.index.toDouble();
      } else {
        _c.duration = spec.duration;
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final slot = box.maxWidth / widget.count;
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final x =
                slot * position + (slot - SaartheeNavigationBar.pillWidth) / 2;
            // Stretch up to 1.4× at mid-flight.
            final stretch =
                1 +
                0.4 * (1 - (2 * _c.value - 1).abs()) * (_c.isAnimating ? 1 : 0);
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 12,
                  child: Transform.translate(
                    offset: Offset(x, 0),
                    child: Transform.scale(
                      scaleX: stretch,
                      child: Container(
                        key: const Key('nav.pill'),
                        width: SaartheeNavigationBar.pillWidth,
                        height: SaartheeNavigationBar.pillHeight,
                        decoration: ShapeDecoration(
                          color: widget.color,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
