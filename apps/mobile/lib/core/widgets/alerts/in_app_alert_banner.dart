import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../config/timings.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/icons.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import 'alert_widgets.dart';

/// Scale of the single Critical attention pulse (1.0 → 1.02 → 1.0).
const double alertPulseScale = 1.02;

/// In-app alert banner (REQ-F-065, DS §6 "New alert while open"): slides
/// down from under the app bar with `springIn`; dismissal slides it back up
/// over `medium`. Critical gets exactly one slow pulse (2 × `long`) after it
/// settles — never repeated. Non-critical hides itself after
/// [AppTimings.alertBannerAutoHide]. Reduced motion: appears/disappears at
/// once, no pulse. Announces "New (critical) alert: title" for TalkBack.
class InAppAlertBanner extends StatefulWidget {
  const InAppAlertBanner({
    super.key,
    required this.severity,
    required this.title,
    required this.onView,
    required this.onDismissed,
  });

  final AlertSeverity severity;
  final String title;
  final VoidCallback onView;

  /// Called after the exit animation (or at once with reduced motion).
  final VoidCallback onDismissed;

  @override
  State<InAppAlertBanner> createState() => InAppAlertBannerState();
}

class InAppAlertBannerState extends State<InAppAlertBanner>
    with TickerProviderStateMixin {
  late final AnimationController slide = AnimationController(vsync: this);
  late final AnimationController pulse = AnimationController(vsync: this);
  Timer? _autoHide;
  bool _started = false;
  bool _leaving = false;

  bool get _critical => widget.severity == AlertSeverity.critical;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final motion = SaartheeMotion.of(context);
    final l10n = AppLocalizations.of(context);
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        _critical
            ? l10n.alertsBannerAnnounceCritical(widget.title)
            : l10n.alertsBannerAnnounce(widget.title),
        Directionality.of(context),
      ),
    );
    if (motion.springIn.isInstant) {
      slide.value = 1;
    } else {
      slide.duration = motion.springIn.duration;
      slide.forward().whenComplete(_settled);
    }
    if (!_critical) {
      _autoHide = Timer(AppTimings.alertBannerAutoHide, dismiss);
    }
  }

  /// One out-and-back pulse; the controller stops for good afterwards.
  void _settled() {
    if (!mounted || !_critical || _leaving) return;
    final motion = SaartheeMotion.of(context);
    if (!motion.transforms) return;
    pulse.duration = motion.long.duration;
    pulse.forward().then((_) {
      if (mounted) pulse.reverse();
    });
  }

  /// Slides the banner up and reports [InAppAlertBanner.onDismissed].
  Future<void> dismiss() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _autoHide?.cancel();
    pulse.stop();
    final spec = SaartheeMotion.of(context).medium;
    if (!SaartheeMotion.of(context).transforms) {
      slide.value = 0;
    } else {
      slide.duration = spec.duration;
      await slide.reverse();
    }
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    slide.dispose();
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final solid = _critical;
    final fg = solid ? NeemFixed.white : SaartheeColors.of(context).textPrimary;
    final banner = SeverityBanner(
      severity: widget.severity,
      message: widget.title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () {
              _autoHide?.cancel();
              widget.onView();
            },
            style: TextButton.styleFrom(foregroundColor: fg),
            child: Text(l10n.alertsBannerView),
          ),
          IconButton(
            tooltip: l10n.alertsBannerDismiss,
            color: fg,
            icon: const Icon(SaartheeIcons.close),
            onPressed: dismiss,
          ),
        ],
      ),
    );
    final curve = SaartheeMotion.springIn.curve;
    return ClipRect(
      child: AnimatedBuilder(
        animation: Listenable.merge([slide, pulse]),
        builder: (context, child) {
          final t = slide.status == AnimationStatus.reverse
              ? SaartheeMotion.standard.transform(slide.value)
              : curve.transform(slide.value);
          final scale =
              1 +
              (alertPulseScale - 1) *
                  SaartheeMotion.long.curve.transform(pulse.value);
          return FractionalTranslation(
            key: const ValueKey('inAppAlertSlide'),
            translation: Offset(0, t - 1),
            child: Opacity(
              opacity: slide.value.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
        child: GestureDetector(
          onTap: widget.onView,
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < 0) dismiss();
          },
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Material(
                type: MaterialType.transparency,
                elevation: 0,
                child: banner,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
